/**
* This is Phedex login component that allows user to login into PhEDEx system using password or certificates 
* and thereby also view user role information. auth data service is used for user authentication
* @namespace PHEDEX
* @class Login
* @constructor
* @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
*/

PHEDEX.namespace('Login');
PHEDEX.Login = function(sandbox) {
    var PxD = PHEDEX.Datasvc;
    var _sbx = sandbox;

    /*
    * _cur_state indicates the current state (login, logout, certlogin, usepassword)
    * login       - use password based authentication.
    * logout      - authenticated using password based authentication and can view his role info
    * certlogin   - use certificate based authentication.
    * usepassword - authenticated using certificate based authentication and can login using password based auth
    */
    var _cur_state = '';    //Current state of browser authentication
    var _logincomp = {};    //Login component main HTML element
    var _username = '';     //Login user name
    var _authData = null;   //Response received from auth data service call
    var _closebtn = null;   //The close button in YUI overlay
    var _bVisible = false;  //Stores the current status of overlay if it is visible or not
    var _user_role_info = null; //The YUI overlay object that has user role information
    var _username_id = 'phedex-login-usrname'; //Used for positioning overlay while display

    /**
    * @method _showOverlay
    * @description This displays the user role information as YUI overlay dialog.
    * @private
    */
    var _showOverlay = function() {
        if (!_authData.role) {
            //There is no user role information in the received response
            banner('There is no role assigned to this user.', 'info');
            return;
        }
        if (_user_role_info) {
            //The YUI overlay is filled with user role information
            if (_bVisible) {
                _user_role_info.hide(); //Hide the YUI overlay if it is visible to user
                _bVisible = false;
                log('The user role information is hidden now', 'info', 'login');
            }
            else {
                _user_role_info.show(); //Show the YUI overlay if it is not visible to user
                _bVisible = true;
                log('The user role information is shown now', 'info', 'login');
            }
        }
    }

    /**
    * @method _closeOverlay
    * @description This hides the user role information (YUI overlay dialog).
    * @private
    */
    var _closeOverlay = function() {
        _user_role_info.hide();
        _bVisible = false;
        log('The user role information is hidden now', 'info', 'login');
    }

    /**
    * @method _formUserInfo
    * @description This creates the YUI overlay object and creates a table in overlay object to populate
    * the user role information.
    * @private
    */
    var _formUserInfo = function() {
        if (_authData.role) {
            if (_authData.role.length > 0) {
                if (!_user_role_info) {
                    //Create a new YUI overlay to show user role information
                    _user_role_info = new YAHOO.widget.Overlay("_user_role_info", { context: [_username_id, "tl", "bl", ["beforeShow", "windowResize"]], visible: false, width: "300px" });
                    log('The user role information YUI overlay is created', 'info', 'login');
                }
                else {
                    //Delete the previous YUI overlay body content
                    while (_user_role_info.body.hasChildNodes()) {
                        _user_role_info.body.removeChild(_user_role_info.body.lastChild);
                    }
                    log('The user role information YUI overlay body content is destroyed', 'info', 'login');
                }
                var overlayBody = document.createElement('div');
                overlayBody.className = 'phedex-login-overlay-body';
                var title = document.createElement('div');
                title.innerHTML = 'User Role Information';
                overlayBody.appendChild(title);
                overlayBody.appendChild(document.createElement('br'));
                var tableUserInfo = document.createElement('table'); //Create a table to show user role information
                tableUserInfo.border = 3;
                tableUserInfo.cellSpacing = 3;
                tableUserInfo.cellPadding = 3;
                var indx = 0, tableRow, tableCell1, tableCell2;
                for (indx = 0; indx < _authData.role.length; indx++) {
                    //Create rows in the table to fill user role information 
                    tableRow = tableUserInfo.insertRow(0);
                    tableCell1 = tableRow.insertCell(0);
                    tableCell2 = tableRow.insertCell(1);
                    tableCell1.innerHTML = _authData.role[indx].name;
                    tableCell2.innerHTML = _authData.role[indx].group;
                }
                tableRow = tableUserInfo.insertRow(0);
                tableRow.className = 'phedex-login-userrole';
                tableCell1 = tableRow.insertCell(0);
                tableCell2 = tableRow.insertCell(1);
                tableCell1.innerHTML = 'Name';
                tableCell2.innerHTML = 'Group';
                overlayBody.appendChild(tableUserInfo);
                overlayBody.appendChild(document.createElement('br'));
                var closebtn = document.createElement('div');
                closebtn.id = 'phedex-login-info-close';
                overlayBody.appendChild(closebtn);
                _user_role_info.setBody(overlayBody);   //Fill the YUI overlay body with user role information table
                _user_role_info.render(document.body);  //Render the YUI overlay
                log('The user role information YUI overlay is rendered', 'info', 'login');
                //Create a button within YUI overlay to allow user to hide YUI overlay (on clicking the button)
                _closebtn = new YAHOO.widget.Button({ label: "Close", id: "buttonClose", container: 'phedex-login-info-close', onclick: { fn: _closeOverlay} });
                log('The user role information YUI overlay body content close button is created', 'info', 'login');
            }
        }
    };

    /**
    * @method _validateLogin
    * @description The validates if user authentication succeeded or not
    * @param {Object} data is the reponse received from from auth data service call.
    * @return {boolean} true if login is successful and false if login is not successful.
    * @private
    */
    var _validateLogin = function(data) {
        if (!data.auth) { //Check if reponse has auth info (to be on safer side)
            return false;
        }
        else {
            if (data.auth[0].state == 'failed') { //Authentication failed
                return false;
            }
        }
        return true; //Authentication succeeded
    }

    /**
    * @method _processLogin
    * @description The response received from from auth data service call is processed and UI is 
    * updated based on authentication type.
    * @param {Object} data is the reponse received from from auth data service call.
    * @private
    */
    var _processLogin = function(data) {
        var bsucceed = _validateLogin(data);
        log('The user login is validated. User credentials are ' + bsucceed, 'info', 'login');
        if (bsucceed) { //Authentication succeeded
            _authData = data.auth[0]; //The user data is saved for further use
            _username = _authData.human_name; //Get the user name
            _logincomp.username.innerHTML = _username;
            if (_authData.state == 'cert') { //Authentication done using certificate 
                _logincomp.statusmsg.innerHTML = ' logged in via certificate';
                _cur_state = 'usepassword';
                _updateLoginButton('Use Password');
            }
            else if (_authData.state == 'passwd') { //Authentication done using password
                _logincomp.statusmsg.innerHTML = ' logged in via password';
                _cur_state = 'logout';
                _updateLoginButton('Log Out');
            }
            YAHOO.util.Dom.addClass(_logincomp.logininput, 'phedex-invisible'); //Hide the login input elements
            log('Updated valid user login authentication info on UI', 'info', 'login');
            _formUserInfo(); //Form the overlay object if authentication succeeded
        }
        else { //Authentication failed
            if (_cur_state != 'certlogin') {
                //Alert user if authentication failed in password mode
                banner('Login failed. Please check login user credential details.', 'error');
            }
            _resetLoginState(); //Set the mode to password state if authentication is failed
        }
    };

    /**
    * @method _loginCallFailure
    * @description This gets called when there is some problem in making auth data service call 
    * and user is informed about this
    * @param {Object} data is the error reponse received.
    * @private
    */
    var _loginCallFailure = function(data) {
        _resetLoginState(); //Set the mode to password state if authentication is failed
        banner('Unable to login. Please try again.', 'error');
        log('Unable to login because of communication failure to make data service call', 'error', 'login');
    };

    var _eventSuccess = new YAHOO.util.CustomEvent('login success');
    var _eventFailure = new YAHOO.util.CustomEvent('login failure');

    _eventSuccess.subscribe(function(type, args) { _processLogin(args[0]); });
    _eventFailure.subscribe(function(type, args) { _loginCallFailure(args[0]); });

    /**
    * @method _onLogin
    * @description This gets called when user click the button and process user request based on authenticatoin mode.
    * @param {Object} event is the event data.
    * @private
    */
    var _onLogin = function(event) {
        if (_bVisible) {
            //Hide YUI overlay user role information just in case if it is open before changing current state
            _user_role_info.hide();
            _bVisible = false;
        }
        if (_cur_state == 'login') {
            if (!_logincomp.inputname.value) {
                banner('Please enter user name', 'warn');
                return;
            }
            if (!_logincomp.inputpwd.value) {
                banner('Please enter password', 'warn');
                return;
            }
            var _pwd = _logincomp.inputpwd.value;
            _username = _logincomp.inputname.value;
            log('Auth data service call is made for password based authentication', 'info', 'login');
            PHEDEX.Datasvc.Call({ type:'POST', api: 'auth', args: { SecModLogin:_username, SecModPwd:_pwd }, success_event: _eventSuccess, failure_event: _eventFailure });
        }
        else if (_cur_state == 'logout') {
            _resetLoginState();
            log('Login components are reset as user clicked logout', 'info', 'login');
        }
        else if (_cur_state == 'usepassword') {
            _resetLoginState();
            _username = '';
            log('Login components are reset as user clicked use password', 'info', 'login');
        }
    };

    /**
    * @method _updateLoginButton
    * @description This updates the text of the button based on current authentication mode.
    * @param {Object} event is the event data.
    * @private
    */
    var _updateLoginButton = function(status) {
        _logincomp.objBtn.set('label', status);
    };

    /**
    * @method _loginUsingCert
    * @description This makes data service call to authenticate using certificate.
    * @private
    */
    var _loginUsingCert = function() {
        _cur_state = 'certlogin';
        log('Auth data service call is made for certificate based authentication', 'info', 'login');
        PHEDEX.Datasvc.Call({ type: 'POST', api: 'auth', success_event: _eventSuccess, failure_event: _eventFailure });
    };

    /**
    * @method _resetLoginState
    * @description This resets the UI back to login mode i.e show user name and password text box
    * @private
    */
    var _resetLoginState = function() {
        YAHOO.util.Dom.removeClass(_logincomp.logininput, 'phedex-invisible'); //Show the login elements
        _logincomp.inputpwd.value = '';
        _logincomp.inputname.value = '';
        _logincomp.username.innerHTML = '';
        _logincomp.statusmsg.innerHTML = '';
        _updateLoginButton('Login');
        _cur_state = 'login';
    };

    /**
    * @method _initLoginComponent
    * @description This creates the login component.
    * @param {HTML element} divlogin element specifies element where login component should be built.
    * @private
    */
    var _initLoginComponent = function(divlogin) {
        if ( !divlogin ) { divlogin = document.getElementById('phedex-login'); }
        var logincomp = PxU.makeChild(divlogin, 'div', { id: 'phedex-nav-login', className: 'phedex-login' });
        logincomp.username = PxU.makeChild(logincomp, 'a', { className: 'phedex-login-username' });
        logincomp.username.id = _username_id;
        logincomp.statusmsg = PxU.makeChild(logincomp, 'span', { className: 'phedex-login-status' });
        logincomp.logininput = PxU.makeChild(logincomp, 'span', { className: 'phedex-invisible' });
        var labelname = PxU.makeChild(logincomp.logininput, 'span');
        labelname.innerHTML = 'User Name: ';
        logincomp.inputname = PxU.makeChild(logincomp.logininput, 'input', { type: 'text' });
        labelname = PxU.makeChild(logincomp.logininput, 'span');
        labelname.innerHTML = '&nbsp;Password: ';
        logincomp.inputpwd = PxU.makeChild(logincomp.logininput, 'input', { type: 'password' });
        var btnsubmit = PxU.makeChild(logincomp, 'span');
        YAHOO.util.Event.addListener(logincomp.username, 'click', _showOverlay, this, true);
        logincomp.objBtn = new YAHOO.widget.Button({ label: 'Login', id: 'buttonOK', container: btnsubmit, onclick: { fn: _onLogin} });
        _logincomp = logincomp;
        log('The login component is created', 'info', 'login');
    };

    //Used to construct the login component.
    _construct = function() {
        return {
            /**
            * @method init
            * @description This creates the login component
            * @param {Object} args object specifies the 'el' element where login component should be built
            */
            init: function(args) {
                var el;
                if ( typeof(args) == 'object' ) { el = args.el; }
                _initLoginComponent(el);
                _loginUsingCert();
            }
        };
    }
    Yla(this, _construct(), true);
};
PHEDEX.Core.onLoaded('login');
log('loaded...','info','login');