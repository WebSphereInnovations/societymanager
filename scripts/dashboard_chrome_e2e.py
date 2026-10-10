from pathlib import Path
import json, re, time, urllib.request, websocket, base64

ROOT = Path(r'C:\Users\Delta\Society360')
LOGIN_SCRIPT = (ROOT / 'scripts' / 'login-ui.ps1').read_text(encoding='utf-8')
values = re.findall(r"SetValue\('([^']*)'\)", LOGIN_SCRIPT)
if len(values) < 2:
    raise RuntimeError('Authorized test-login configuration was not found.')
login, password = values[0], values[1]
pages = json.load(urllib.request.urlopen('http://127.0.0.1:9335/json/list'))
page = next((x for x in pages if x.get('type') == 'page' and '192.168.1.8:5180' in x.get('url', '')), None)
if not page:
    raise RuntimeError('Chrome page for the required application endpoint was not found.')
ws = websocket.create_connection(page['webSocketDebuggerUrl'], timeout=10, origin='http://127.0.0.1:9335')
seq = 0
events = []

def cmd(method, params=None):
    global seq
    seq += 1
    ws.send(json.dumps({'id': seq, 'method': method, 'params': params or {}}))
    while True:
        msg = json.loads(ws.recv())
        if msg.get('id') == seq:
            if 'error' in msg:
                raise RuntimeError(method + ': ' + str(msg['error']))
            return msg.get('result', {})
        if msg.get('method'):
            events.append(msg)

def evaluate(expr, await_promise=False):
    r = cmd('Runtime.evaluate', {'expression': expr, 'returnByValue': True, 'awaitPromise': await_promise, 'userGesture': True})
    if r.get('exceptionDetails'):
        return {'exception': r['exceptionDetails'].get('text', 'evaluation error')}
    return r.get('result', {}).get('value')

def wait(sec=1.0):
    time.sleep(sec)
    old_timeout = ws.gettimeout()
    ws.settimeout(0.15)
    try:
        while True:
            try:
                msg = json.loads(ws.recv())
                if msg.get('method'):
                    events.append(msg)
            except Exception:
                break
    finally:
        ws.settimeout(old_timeout)

def box(selector):
    doc = cmd('DOM.getDocument', {'depth': 1})['root']['nodeId']
    node = cmd('DOM.querySelector', {'nodeId': doc, 'selector': selector}).get('nodeId', 0)
    if not node:
        return None
    try:
        cmd('DOM.scrollIntoViewIfNeeded', {'nodeId': node})
    except Exception:
        pass
    try:
        model = cmd('DOM.getBoxModel', {'nodeId': node})['model']['content']
    except Exception:
        return None
    xs, ys = model[0::2], model[1::2]
    return (sum(xs)/len(xs), sum(ys)/len(ys))

def hover(selector):
    point = box(selector)
    if not point:
        return False
    cmd('Input.dispatchMouseEvent', {'type':'mouseMoved','x':point[0],'y':point[1]})
    return True

def click(selector):
    doc = cmd('DOM.getDocument', {'depth': 1})['root']['nodeId']
    node = cmd('DOM.querySelector', {'nodeId': doc, 'selector': selector}).get('nodeId', 0)
    if not node:
        return False
    try:
        cmd('DOM.scrollIntoViewIfNeeded', {'nodeId': node})
    except Exception:
        pass
    try:
        model = cmd('DOM.getBoxModel', {'nodeId': node})['model']['content']
    except Exception:
        return False
    xs, ys = model[0::2], model[1::2]
    x, y = sum(xs)/len(xs), sum(ys)/len(ys)
    cmd('Input.dispatchMouseEvent', {'type':'mouseMoved','x':x,'y':y})
    cmd('Input.dispatchMouseEvent', {'type':'mousePressed','x':x,'y':y,'button':'left','clickCount':1})
    cmd('Input.dispatchMouseEvent', {'type':'mouseReleased','x':x,'y':y,'button':'left','clickCount':1})
    return True

cmd('Page.enable')
cmd('Runtime.enable')
cmd('Network.enable')
cmd('Log.enable')
cmd('DOM.enable')
initial_page=evaluate("JSON.stringify({url:location.href,home:!!document.querySelector('#dashboardKpis')})")
initial_page=json.loads(initial_page) if isinstance(initial_page,str) else initial_page
if not initial_page.get('home'):
    cmd('Page.navigate', {'url':'http://192.168.1.8:5180/modules/society-admin/index.html'})
    wait(2.0)
session_probe=evaluate("(async()=>{const r=await fetch('/api/auth/me',{cache:'no-store'});const j=await r.json().catch(()=>({}));return {status:r.status,loginName:j.loginName||j.login||j.user?.loginName||null}})()",True)
if isinstance(session_probe,str):
    try:session_probe=json.loads(session_probe)
    except Exception:session_probe={}
home_present=bool(evaluate("!!document.querySelector('#dashboardKpis')"))
login_result={'submitted':False,'existingSession':bool(isinstance(session_probe,dict) and session_probe.get('status')==200 and home_present)}
if not login_result['existingSession']:
    cmd('Page.navigate', {'url':'http://192.168.1.8:5180/login.html'})
    wait(1.0)
    expr = "(()=>{const l=document.querySelector('#login'),p=document.querySelector('#password'),f=document.querySelector('#login-form');if(!l||!p||!f)return {submitted:false,url:location.href};l.value=" + json.dumps(login) + ";p.value=" + json.dumps(password) + ";l.dispatchEvent(new Event('input',{bubbles:true}));p.dispatchEvent(new Event('input',{bubbles:true}));f.requestSubmit();return {submitted:true}})()"
    login_result = evaluate(expr)
    wait(5.0)
post_login = evaluate("JSON.stringify({url:location.href,title:document.title,home:!!document.querySelector('#dashboardKpis'),dashboardStatus:document.querySelector('#dashboardStatus')?.textContent||'',dashboardError:document.querySelector('#dashboardError')?.textContent||'',loginError:document.querySelector('#error')?.textContent||'',loginStillVisible:!!document.querySelector('#login-form')})")
post_login = json.loads(post_login) if isinstance(post_login, str) else post_login
if not post_login.get('home'):
    raise RuntimeError('Authorized session/login did not reach the dashboard: ' + json.dumps({'page':post_login,'loginAttempt':login_result,'existingSessionValid':isinstance(session_probe,dict) and session_probe.get('status')==200}, ensure_ascii=False))
evaluate("(()=>{if(!document.querySelector('#home')?.classList.contains('active'))window.societyAdminShow?.('home','Dashboard');return true})()")
wait(0.6)
click('#dashReset')
wait(0.8)

api = evaluate("(async()=>{const r=await fetch('/api/society-admin/dashboard/analytics?from=2026-10-01&to=2026-10-10',{cache:'no-store'});const j=await r.json();return {status:r.status,keys:Object.keys(j),summary:j.summary||null,period:j.period||null,trendCount:(j.trends||[]).length,occupancyCount:(j.occupancy||[]).length,paymentModeCount:(j.paymentModes||[]).length,customerTypes:j.customerTypes||[],unitTypes:j.unitTypes||[],billStatuses:j.billStatuses||[],filters:j.filters?{buildings:j.filters.buildings?.length||0,unitTypes:j.filters.unitTypes?.length||0,paymentModes:j.filters.paymentModes?.length||0}:null}})()", True)
if isinstance(api, str): api = json.loads(api)
bill_endpoint_probe = evaluate("(async()=>{const r=await fetch('/api/society-admin/bills?q=',{cache:'no-store'});const ct=r.headers.get('content-type')||'';const body=await r.text();return {status:r.status,contentType:ct,bodyStart:body.slice(0,80).replace(/\\s+/g,' ')}})()", True)
if isinstance(bill_endpoint_probe,str):
    try: bill_endpoint_probe=json.loads(bill_endpoint_probe)
    except Exception: pass

ui = evaluate("JSON.stringify({kpis:document.querySelectorAll('.dash-kpi').length,trendSvg:!!document.querySelector('#dashboardTrend svg'),occupancyDonut:!!document.querySelector('#dashboardOccupancy .dash-donut'),paymentDonut:!!document.querySelector('#dashboardPaymentModes .dash-donut'),breakdownBars:document.querySelectorAll('.dash-bar-row').length,filterCount:document.querySelectorAll('.dash-filters select,.dash-filters input').length,period:document.querySelector('#dashboardPeriodLabel')?.textContent||'',status:document.querySelector('#dashboardStatus')?.textContent||'',errorHidden:document.querySelector('#dashboardError')?.hidden,tooltips:document.querySelectorAll('#dashboardTrend circle title').length})")
ui = json.loads(ui) if isinstance(ui, str) else ui
# Isolated DOM-level Chrome drill-down probe: invoke the same click handlers without coordinate/box-model timing.
evaluate("document.querySelector('[data-dash-drill=\"overdue\"]')?.click();")
wait(0.9)
drill_modal=evaluate("JSON.stringify({open:!document.querySelector('#dashboardDrillModal')?.hidden,title:document.querySelector('#dashboardDrillTitle')?.textContent||'',rows:document.querySelectorAll('#dashboardDrillTableWrap tbody tr').length,state:document.querySelector('#dashboardDrillState')?.textContent||''})")
if isinstance(drill_modal,str): drill_modal=json.loads(drill_modal)
evaluate("document.querySelector('#dashboardDrillOpenModule')?.click()")
wait(0.9)
drill_destination=evaluate("JSON.stringify({activeViews:[...document.querySelectorAll('.view.active')].map(x=>x.id),billsActive:document.querySelector('#bills')?.classList.contains('active'),billTable:!!document.querySelector('#billTable'),modalHidden:document.querySelector('#dashboardDrillModal')?.hidden})")
if isinstance(drill_destination,str): drill_destination=json.loads(drill_destination)
evaluate("window.societyAdminShow?.('home','Dashboard')")
wait(0.6)
# Filter, localization, and responsive probe (kept separate from drill-down navigation).
evaluate("(()=>{const e=document.querySelector('#dashPreset');e.value='week';e.dispatchEvent(new Event('change',{bubbles:true}));return true})()")
wait(1.2)
period_test=evaluate("JSON.stringify({preset:document.querySelector('#dashPreset')?.value,from:document.querySelector('#dashFrom')?.value,to:document.querySelector('#dashTo')?.value,label:document.querySelector('#dashboardPeriodLabel')?.textContent})")
if isinstance(period_test,str): period_test=json.loads(period_test)
filter_test=evaluate("(()=>{const ids=['#dashBuilding','#dashUnitType','#dashCustomerType','#dashPaymentMode','#dashBillStatus'];const selected={};for(const id of ids){const e=document.querySelector(id);const o=[...e.options].find(x=>x.value);if(o){e.value=o.value;selected[id]=e.value}}document.querySelector('#dashApply').click();return JSON.stringify(selected)})()")
if isinstance(filter_test,str):
    try: filter_test=json.loads(filter_test)
    except Exception: pass
wait(1.2)
filter_result=evaluate("JSON.stringify({selected:"+json.dumps(filter_test)+",errorHidden:document.querySelector('#dashboardError')?.hidden,period:document.querySelector('#dashboardPeriodLabel')?.textContent,customers:document.querySelector('#kpiCustomers')?.textContent,flats:document.querySelector('#kpiFlats')?.textContent})")
if isinstance(filter_result,str): filter_result=json.loads(filter_result)
languages={}
for code in ['hi','mr','gu','kn','ta','en']:
    evaluate("(()=>{const e=document.querySelector('#language-select');e.value="+json.dumps(code)+";e.dispatchEvent(new Event('change',{bubbles:true}));return true})()")
    wait(0.4)
    val=evaluate("JSON.stringify({language:window.Society360I18n?.currentLanguage?.(),heading:document.querySelector('#home .dash-hero h2')?.textContent||'',status:document.querySelector('#dashboardStatus')?.textContent||'',garbage:(document.querySelector('#home')?.innerText||'').includes('????')||(document.querySelector('#home')?.innerText||'').includes('�')})")
    languages[code]=json.loads(val) if isinstance(val,str) else val
viewports=[]
for width,height,mobile in [(390,844,True),(768,1024,True),(1366,900,False),(1920,1080,False)]:
    cmd('Emulation.setDeviceMetricsOverride',{'width':width,'height':height,'deviceScaleFactor':1,'mobile':mobile})
    wait(0.3)
    val=evaluate("JSON.stringify({width:innerWidth,height:innerHeight,bodyScroll:document.body.scrollWidth,docScroll:document.documentElement.scrollWidth,overflow:document.body.scrollWidth>innerWidth||document.documentElement.scrollWidth>innerWidth,kpis:document.querySelectorAll('.dash-kpi').length,filters:!!document.querySelector('.dash-filters')})")
    viewports.append(json.loads(val) if isinstance(val,str) else val)
cmd('Emulation.clearDeviceMetricsOverride')
bad_range=evaluate("(async()=>{const r=await fetch('/api/society-admin/dashboard/analytics?from=2026-10-10&to=2026-10-01',{cache:'no-store'});return {status:r.status,body:await r.json()}})()",True)
if isinstance(bad_range,str):
    try: bad_range=json.loads(bad_range)
    except Exception: pass
evaluate("(()=>{document.querySelector('#dashPreset').value='custom';document.querySelector('#dashFrom').value='1990-01-01';document.querySelector('#dashTo').value='1990-01-02';document.querySelector('#dashApply').click();return true})()")
wait(1.2)
empty_test=evaluate("JSON.stringify({emptyStates:document.querySelectorAll('.dash-empty-state').length,errorHidden:document.querySelector('#dashboardError')?.hidden,status:document.querySelector('#dashboardStatus')?.textContent||''})")
if isinstance(empty_test,str): empty_test=json.loads(empty_test)
console_errors=[]
http_errors=[]
for ev in events:
    if ev.get('method')=='Runtime.exceptionThrown':
        console_errors.append(ev.get('params',{}).get('exceptionDetails',{}).get('text','Runtime exception'))
    elif ev.get('method')=='Log.entryAdded' and ev.get('params',{}).get('entry',{}).get('level')=='error':
        console_errors.append(ev.get('params',{}).get('entry',{}).get('text','Console error'))
    elif ev.get('method')=='Network.responseReceived':
        resp=ev.get('params',{}).get('response',{})
        if resp.get('status',200)>=400:
            http_errors.append({'status':resp.get('status'),'url':resp.get('url','')[:180]})
print(json.dumps({'drillModal':drill_modal,'drillDestination':drill_destination,'period':period_test,'filters':filter_result,'languages':languages,'viewports':viewports,'invalidRange':bad_range,'emptyState':empty_test,'consoleErrors':console_errors[:20],'httpErrors':http_errors[:20]},ensure_ascii=True,default=str),flush=True)
raise SystemExit(0)
clicked_bills = click('[data-dash-drill="overdue"]')
wait(1.0)
drill_modal = evaluate("JSON.stringify({open:!document.querySelector('#dashboardDrillModal')?.hidden,title:document.querySelector('#dashboardDrillTitle')?.textContent||'',state:document.querySelector('#dashboardDrillState')?.textContent||'',rows:document.querySelectorAll('#dashboardDrillTableWrap tbody tr').length,count:document.querySelector('#dashboardDrillCount')?.textContent||''})")
drill_modal = json.loads(drill_modal) if isinstance(drill_modal, str) else drill_modal
print(json.dumps({'drillModal':drill_modal},ensure_ascii=True,default=str),flush=True)
raise SystemExit(0)
open_module_clicked = click('#dashboardDrillOpenModule')
wait(1.2)
drill = evaluate("JSON.stringify({billsActive:document.querySelector('#bills')?.classList.contains('active'),billTable:!!document.querySelector('#billTable'),activeViews:[...document.querySelectorAll('.view.active')].map(x=>x.id),modalClosed:document.querySelector('#dashboardDrillModal')?.hidden})")
drill = json.loads(drill) if isinstance(drill, str) else drill
# Return to the Dashboard using the actual app navigation button where available.
home_clicked = click('#dbMenu button[data-view="home"]')
if not home_clicked:
    evaluate("window.societyAdminShow?.('home','Dashboard')")
wait(1.0)
# Click an actual customer category segment and verify the modal receives a category-filtered record set.
customer_chart_clicked = click('#dashboardKpis [data-dash-drill="customers"]')
wait(0.8)
customer_drill = evaluate("JSON.stringify({open:!document.querySelector('#dashboardDrillModal')?.hidden,title:document.querySelector('#dashboardDrillTitle')?.textContent||'',subtitle:document.querySelector('#dashboardDrillSubtitle')?.textContent||'',rows:document.querySelectorAll('#dashboardDrillTableWrap tbody tr').length,state:document.querySelector('#dashboardDrillState')?.textContent||''})")
customer_drill = json.loads(customer_drill) if isinstance(customer_drill, str) else customer_drill
print(json.dumps({'drill':{'clicked':clicked_bills,'modal':drill_modal,'openModuleClicked':open_module_clicked,**drill},'customerCategoryDrilldown':{'clicked':customer_chart_clicked,**customer_drill}},ensure_ascii=True,default=str),flush=True)
raise SystemExit(0)
click('#dashboardDrillClose')
wait(0.3)

# Change reporting preset and verify dates/data reload.
evaluate("(()=>{const e=document.querySelector('#dashPreset');e.value='week';e.dispatchEvent(new Event('change',{bubbles:true}));return true})()")
wait(1.5)
period_test = evaluate("JSON.stringify({preset:document.querySelector('#dashPreset')?.value,from:document.querySelector('#dashFrom')?.value,to:document.querySelector('#dashTo')?.value,label:document.querySelector('#dashboardPeriodLabel')?.textContent})")
period_test = json.loads(period_test) if isinstance(period_test, str) else period_test
# Select available live filter values and verify the Dashboard request completes without a UI error.
filter_test = evaluate("(()=>{const ids=['#dashBuilding','#dashUnitType','#dashCustomerType','#dashPaymentMode','#dashBillStatus'];const selected={};for(const id of ids){const e=document.querySelector(id);const o=[...e.options].find(x=>x.value);if(o){e.value=o.value;selected[id]=e.value}}document.querySelector('#dashApply').click();return JSON.stringify(selected)})()")
if isinstance(filter_test, str):
    try: filter_test=json.loads(filter_test)
    except Exception: pass
wait(1.3)
filter_result = evaluate("JSON.stringify({selected:" + json.dumps(filter_test) + ",errorHidden:document.querySelector('#dashboardError')?.hidden,period:document.querySelector('#dashboardPeriodLabel')?.textContent,customers:document.querySelector('#kpiCustomers')?.textContent,flats:document.querySelector('#kpiFlats')?.textContent})")
filter_result = json.loads(filter_result) if isinstance(filter_result, str) else filter_result
# Apply an impossible/empty historical range and check that empty chart states render without fabricated values.
evaluate("(()=>{document.querySelector('#dashPreset').value='custom';document.querySelector('#dashFrom').value='1990-01-01';document.querySelector('#dashTo').value='1990-01-02';document.querySelector('#dashApply').click();return true})()")
wait(1.5)
empty_test = evaluate("JSON.stringify({from:document.querySelector('#dashFrom')?.value,to:document.querySelector('#dashTo')?.value,chartEmpty:document.querySelectorAll('.dash-empty-state').length,apiStatus:document.querySelector('#dashboardError')?.hidden?'ok':'error'})")
empty_test = json.loads(empty_test) if isinstance(empty_test, str) else empty_test
# Restore current month before localization and viewport checks.
evaluate("(()=>{document.querySelector('#dashPreset').value='month';document.querySelector('#dashPreset').dispatchEvent(new Event('change',{bubbles:true}));return true})()")
wait(1.2)

languages = {}
for code in ['hi','mr','gu','kn','ta','en']:
    evaluate("(()=>{const e=document.querySelector('#language-select');e.value=" + json.dumps(code) + ";e.dispatchEvent(new Event('change',{bubbles:true}));return true})()")
    wait(0.6)
    val = evaluate("JSON.stringify({language:window.Society360I18n?.currentLanguage?.(),heading:document.querySelector('#home .dash-hero h2')?.textContent||'',shellHeading:document.querySelector('#heading')?.textContent||'',shellSubtitle:document.querySelector('header p')?.textContent||'',status:document.querySelector('#dashboardStatus')?.textContent||'',garbage:(document.querySelector('#home')?.innerText||'').includes('????')||(document.querySelector('#home')?.innerText||'').includes('�')})")
    languages[code] = json.loads(val) if isinstance(val, str) else val

viewports = []
for width,height,mobile in [(390,844,True),(768,1024,True),(1366,900,False),(1920,1080,False)]:
    cmd('Emulation.setDeviceMetricsOverride', {'width':width,'height':height,'deviceScaleFactor':1,'mobile':mobile})
    wait(0.35)
    val = evaluate("JSON.stringify({width:innerWidth,height:innerHeight,bodyScroll:document.body.scrollWidth,docScroll:document.documentElement.scrollWidth,overflow:document.body.scrollWidth>innerWidth||document.documentElement.scrollWidth>innerWidth,kpis:document.querySelectorAll('.dash-kpi').length,filters:!!document.querySelector('.dash-filters'),chartWidth:Math.round(document.querySelector('#dashboardTrend')?.getBoundingClientRect().width||0)})")
    viewport_data=json.loads(val) if isinstance(val, str) else val
    viewports.append(viewport_data)
    if width==390:
        shot=cmd('Page.captureScreenshot', {'format':'png','captureBeyondViewport':False})
        if shot.get('data'):(ROOT/'scripts'/'dashboard-chrome-mobile.png').write_bytes(base64.b64decode(shot['data']))
        menu_open=click('#mobileMenuToggle')
        wait(0.2)
        viewport_data['mobileMenuOpens']=evaluate("JSON.stringify({open:document.querySelector('.side')?.classList.contains('mobile-open'),backdrop:document.querySelector('#mobileMenuBackdrop')?.classList.contains('visible'),expanded:document.querySelector('#mobileMenuToggle')?.getAttribute('aria-expanded')})")
        if isinstance(viewport_data['mobileMenuOpens'],str):viewport_data['mobileMenuOpens']=json.loads(viewport_data['mobileMenuOpens'])
        # Click the exposed area outside the 245px drawer rather than its center (which lies under the drawer).
        mx,my=370,422
        cmd('Input.dispatchMouseEvent', {'type':'mouseMoved','x':mx,'y':my})
        cmd('Input.dispatchMouseEvent', {'type':'mousePressed','x':mx,'y':my,'button':'left','clickCount':1})
        cmd('Input.dispatchMouseEvent', {'type':'mouseReleased','x':mx,'y':my,'button':'left','clickCount':1})
        wait(0.2)
        viewport_data['mobileMenuCloses']=not bool(evaluate("document.querySelector('.side')?.classList.contains('mobile-open')"))
        hover('.dash-kpi')
        hover('#dashboardTrend circle')
        viewport_data['hoverTargets']={'kpi':True,'trendTooltip':bool(evaluate("!!document.querySelector('#dashboardTrend circle title')"))}
cmd('Emulation.clearDeviceMetricsOverride')
# Recheck backend validation for conflicting dates without changing the visible UI.
bad_range = evaluate("(async()=>{const r=await fetch('/api/society-admin/dashboard/analytics?from=2026-10-10&to=2026-10-01',{cache:'no-store'});return {status:r.status,body:await r.json()}})()", True)
if isinstance(bad_range, str):
    try: bad_range=json.loads(bad_range)
    except Exception: pass

wait(0.5)
console_errors = []
http_errors = []
html_api_responses = []
for ev in events:
    m = ev.get('method','')
    p = ev.get('params',{})
    if m == 'Runtime.exceptionThrown':
        details=p.get('exceptionDetails',{})
        console_errors.append({'text':details.get('text','Runtime exception'),'description':details.get('exception',{}).get('description',''),'stack':details.get('stackTrace',{}).get('callFrames',[])[:3]})
    elif m == 'Log.entryAdded':
        entry = p.get('entry',{})
        if entry.get('level') == 'error':
            console_errors.append({'text':entry.get('text','Console error'),'url':entry.get('url',''),'stack':entry.get('stackTrace',{}).get('callFrames',[])[:3]})
    elif m == 'Network.responseReceived':
        response = p.get('response',{})
        url=response.get('url','')
        if response.get('status',200) >= 400:
            http_errors.append({'status':response.get('status'),'url':url[:180]})
        if '/api/' in url and 'text/html' in response.get('mimeType',''):
            html_api_responses.append({'status':response.get('status'),'url':url[:180],'mimeType':response.get('mimeType')})

# Save a screenshot artifact of the tested dashboard at desktop size.
cmd('Emulation.setDeviceMetricsOverride', {'width':1366,'height':900,'deviceScaleFactor':1,'mobile':False})
shot = cmd('Page.captureScreenshot', {'format':'png','captureBeyondViewport':False})
if shot.get('data'):
    (ROOT / 'scripts' / 'dashboard-chrome-desktop.png').write_bytes(base64.b64decode(shot['data']))
cmd('Emulation.clearDeviceMetricsOverride')
ws.close()
print(json.dumps({
 'chrome':'connected',
 'login':{'submitted':bool(login_result.get('submitted')),'url':post_login.get('url'),'title':post_login.get('title'),'dashboardReached':bool(post_login.get('home'))},
 'analyticsApi':api,
 'billEndpointProbe':bill_endpoint_probe,
 'dashboardUi':ui,
 'drilldown':{'clicked':clicked_bills,'modal':drill_modal,'openModuleClicked':open_module_clicked,**drill},
 'customerCategoryDrilldown':{'clicked':customer_chart_clicked,**customer_drill},
 'periodFilter':period_test,
 'propertyAndBusinessFilters':filter_result,
 'emptyRange':empty_test,
 'languages':languages,
 'viewports':viewports,
 'invalidRangeApi':bad_range,
 'consoleErrors':console_errors[:25],
 'httpErrors':http_errors[:25],
 'htmlApiResponses':html_api_responses[:25],
 'screenshots':['scripts/dashboard-chrome-desktop.png','scripts/dashboard-chrome-mobile.png']
}, ensure_ascii=True, default=str))
