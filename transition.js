
document.querySelectorAll("a").forEach(link=>{

if(link.hostname===window.location.hostname){

link.addEventListener("click",e=>{

if(link.href.includes("#")) return;

e.preventDefault();

document.body.style.opacity=0;

setTimeout(()=>{

window.location=link.href;

},300);

});

}

});
