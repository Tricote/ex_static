(()=>{(function(){var d=l();function l(){if(typeof window.CustomEvent=="function")return window.CustomEvent;function t(e,n){n=n||{bubbles:!1,cancelable:!1,detail:void 0};var a=document.createEvent("CustomEvent");return a.initCustomEvent(e,n.bubbles,n.cancelable,n.detail),a}return t.prototype=window.Event.prototype,t}function o(t,e){var n=document.createElement("input");return n.type="hidden",n.name=t,n.value=e,n}function c(t,e){var n=t.getAttribute("data-to"),a=o("_method",t.getAttribute("data-method")),f=o("_csrf_token",t.getAttribute("data-csrf")),i=document.createElement("form"),r=document.createElement("input"),u=t.getAttribute("target");i.method=t.getAttribute("data-method")==="get"?"get":"post",i.action=n,i.style.display="none",u?i.target=u:e&&(i.target="_blank"),i.appendChild(f),i.appendChild(a),document.body.appendChild(i),r.type="submit",i.appendChild(r),r.click()}window.addEventListener("click",function(t){var e=t.target;if(!t.defaultPrevented)for(;e&&e.getAttribute;){var n=new d("phoenix.link.click",{bubbles:!0,cancelable:!0});if(!e.dispatchEvent(n))return t.preventDefault(),t.stopImmediatePropagation(),!1;if(e.getAttribute("data-method"))return c(e,t.metaKey||t.shiftKey),t.preventDefault(),!1;e=e.parentNode}},!1),window.addEventListener("phoenix.link.click",function(t){var e=t.target.getAttribute("data-confirm");e&&!window.confirm(e)&&t.preventDefault()},!1)})();})();
