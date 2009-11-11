/* PHEDEX.Login
 * Login component for the application. Allows user to login into PhEDEx system using auth data service
*/
PHEDEX.namespace("Login");
PHEDEX.Login = (function() {
    var PxU = PHEDEX.Util;
    var PxD = PHEDEX.Datasvc;

    //_mode decides the mode of authentication
    //_mode = 1 indicates password
    //_mode = 2 indicates certificate
    var _mode = 2; //default is password authentication
    var _username = "";
    var _cur_state = "login";

    var _initLoginComponent = function(divlogin) {
        var logincomp = PxU.makeChild(divlogin, 'div', { id: 'phedex-nav-login', className: 'phedex-login' });
        var username = PxU.makeChild(logincomp, 'a', { className: 'phedex-login-username' });
        var statusmsg = PxU.makeChild(logincomp, 'span', { className: 'phedex-login-status' });
        var logininput = PxU.makeChild(logincomp, 'span');
        var labelname = PxU.makeChild(logininput, 'span');
        labelname.innerHTML = "User Name: ";
        var inputname = PxU.makeChild(logininput, 'input', { type: 'text' });
        labelname = PxU.makeChild(logininput, 'span');
        labelname.innerHTML = "&nbsp;Password: ";
        var inputpwd = PxU.makeChild(logininput, 'input', { type: 'password' });
        var btnsubmit = PxU.makeChild(logincomp, 'span');

        var _showUserInfo = function() { //Show user info when user name link is clicked
            alert("User Info function not yet implemented");
        };

        YAHOO.util.Event.addListener(username, 'click', _showUserInfo, this, true);
        var _processLogin = function(data) {
            var bsucceed = true;
            if (bsucceed) {
                _updateLoginButton("Log Out");
                _username = inputname.value;
                username.innerHTML = _username;
                statusmsg.innerHTML = " logged in via password";
                inputpwd.value = "";
                _cur_state = 'logout';
                YAHOO.util.Dom.addClass(logininput, 'phedex-invisible'); //To Hide the element
            }
            else {
                username.innerHTML = "";
                statusmsg.innerHTML = "";
                _cur_state = 'login';
                alert("Login failed. Please enter correct username and password.");
            }
        };

        var _loginCallFailure = function(data) {
            alert("Login check failed. Please try again.");
            return;
        }

        var _eventSuccess = new YAHOO.util.CustomEvent("event success");
        var _eventFailure = new YAHOO.util.CustomEvent("event failure");

        _eventSuccess.subscribe(function(type, args) { _processLogin(args[0]); });
        _eventFailure.subscribe(function(type, args) { _loginCallFailure(args[0]); });
        var _onLogin = function(event) {
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
                PHEDEX.Datasvc.Call({ api: 'bounce', success_event: _eventSuccess, failure_event: _eventFailure });
            }
            else if (_cur_state == 'logout') {
                YAHOO.util.Dom.removeClass(logininput, 'phedex-invisible'); //To Hide the element
                inputpwd.value = "";
                inputname.value = "";
                statusmsg.innerHTML = "";
                username.innerHTML = "";
                _updateLoginButton("Login");
                _cur_state = 'login';
            }
            else if (_cur_state == 'usepassword') {
                YAHOO.util.Dom.removeClass(logininput, 'phedex-invisible'); //To Hide the element
                _username = "";
                inputpwd.value = "";
                inputname.value = "";
                statusmsg.innerHTML = "";
                username.innerHTML = "";
                _updateLoginButton("Login");
                _cur_state = 'login';
            }
        };

        var objBtn = new YAHOO.widget.Button({ label: "Login", id: "buttonOK", container: btnsubmit, onclick: { fn: _onLogin} });

        _updateLoginButton = function(status) {
            objBtn.set("label", status);
        };

        //Check if authenticated using certificate info
        if (_mode == 2) { //If mode is certificate
            _username = "Test User"; //Get user name from certificate
            username.innerHTML = _username;
            statusmsg.innerHTML = " logged in via certificate";
            _cur_state = 'usepassword';
            _updateLoginButton("Use Password");
            YAHOO.util.Dom.addClass(logininput, 'phedex-invisible'); //To Hide the element
        }
    };
    return {
        init: function(el) {
            _initLoginComponent(el);
        }
    };
})();