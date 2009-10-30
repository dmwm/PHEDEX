/* PHEDEX.Login
 * Login component for the application. Allows user to login into PhEDEx system using auth data service
*/
PHEDEX.namespace("Login");
PHEDEX.Login = (function() {
    var PxU = PHEDEX.Util;
    var PxD = PHEDEX.Datasvc;

    var _username = "";
    var _pwd = "";
    var _cur_state = "login";

    var _initLoginComponent = function(divlogin) {
        var logincomp = PxU.makeChild(divlogin, 'div', { id: 'phedex-nav-login', className: 'phedex-login' });
        var labelname = PxU.makeChild(logincomp, 'span');
        labelname.innerHTML = "User Name: ";
        var inputname = PxU.makeChild(logincomp, 'input', { type: 'text' });
        labelname = PxU.makeChild(logincomp, 'span');
        labelname.innerHTML = "&nbsp;&nbsp;Password: ";
        var inputpwd = PxU.makeChild(logincomp, 'input', { type: 'password' });
        var btnsubmit = PxU.makeChild(logincomp, 'span');
        var statusmsg = PxU.makeChild(logincomp, 'div', { className: 'phedex-login-status' });

        var processlogin = function(data) {
            var bsucceed = true;
            if (bsucceed) {
                _updateLoginButton("Log Out");
                statusmsg.innerHTML = inputname.value + " logged in via cert";
                inputpwd.value = "";
                _cur_state = 'logout';
            }
            else {
                statusmsg.innerHTML = "";
                _cur_state = 'login';
                alert("Login failed. Please enter correct username and password.");
            }
        };

        var onLogin = function(event) {
            if (_cur_state == 'login') {
                if (!inputname.value) {
                    alert("Please enter user name");
                    return;
                }
                if (!inputpwd.value) {
                    alert("Please enter password");
                    return;
                }
                _pwd = inputpwd.value;
                _username = inputname.value;
                PHEDEX.Datasvc.Call({ api: 'bounce', callback: processlogin });
            }
            else if (_cur_state == 'logout') {
                inputpwd.value = "";
                inputname.value = "";
                statusmsg.innerHTML = "";
                _updateLoginButton("Login");
                _cur_state = 'login';
            }
        };

        var objBtn = new YAHOO.widget.Button({ label: "Login", id: "buttonOK", container: btnsubmit, onclick: { fn: onLogin} });

        _updateLoginButton = function(status) {
            objBtn.set("label", status);
        };
    };
    return {
        init: function(el) {
            _initLoginComponent(el);
        }
    };
})();
