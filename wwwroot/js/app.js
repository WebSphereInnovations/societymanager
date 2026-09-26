const bills=[
{id:"INV-2609-0412",flat:"A-402",resident:"Aarav Mehta",type:"Maintenance",amount:4850,date:"26 Sep 2026",status:"Paid"},
{id:"INV-2609-0408",flat:"B-1102",resident:"Neha Shah",type:"Maintenance + Parking",amount:6350,date:"26 Sep 2026",status:"Paid"},
{id:"INV-2609-0397",flat:"C-803",resident:"Rohan Patil",type:"Maintenance",amount:4200,date:"25 Sep 2026",status:"Partial"},
{id:"INV-2609-0389",flat:"A-706",resident:"Isha Kulkarni",type:"Maintenance",amount:5100,date:"25 Sep 2026",status:"Pending"},
{id:"INV-2609-0381",flat:"B-504",resident:"Vivek Joshi",type:"Maintenance + Water",amount:5650,date:"24 Sep 2026",status:"Paid"}
];
new Tabulator("#billing-table",{data:bills,layout:"fitColumns",height:"245px",rowHeight:42,responsiveLayout:"collapse",
columns:[
{title:"Invoice",field:"id",width:145},
{title:"Flat",field:"flat",width:72},
{title:"Resident",field:"resident",minWidth:130},
{title:"Type",field:"type",minWidth:145},
{title:"Amount",field:"amount",hozAlign:"right",formatter:c=>"₹"+Number(c.getValue()).toLocaleString("en-IN")},
{title:"Date",field:"date",width:112},
{title:"Status",field:"status",width:85,formatter:c=>{const v=c.getValue();return '<span class="status '+v.toLowerCase()+'">'+v+"</span>"}}
]});
function clock(){const d=new Date();document.querySelector("#clock").textContent=d.toLocaleDateString("en-IN",{weekday:"short",day:"2-digit",month:"short",year:"numeric"})+" · "+d.toLocaleTimeString("en-IN",{hour:"2-digit",minute:"2-digit",second:"2-digit"});}
clock();setInterval(clock,1000);
document.querySelectorAll("nav a").forEach(a=>a.addEventListener("click",()=>{document.querySelectorAll("nav a").forEach(x=>x.classList.remove("active"));a.classList.add("active");}));
document.querySelector(".primary").addEventListener("click",()=>alert("Billing workspace is the next connected module."));
