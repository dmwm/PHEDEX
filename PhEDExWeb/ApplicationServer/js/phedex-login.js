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
        _sbx = sandbox,

    /*
    * _cur_state indicates the current state (login, logout, certlogin, usepassword)
    * login       - use password based authentication.
    * logout      - authenticated using password based authentication and can view his role info
    * certlogin   - use certificate based authentication.
    * usepassword - authenticated using certificate based authentication and can login using password based auth
    */
        _cur_state = '',    //Current state of browser authentication
        _logincomp = {},    //Login component main HTML element
        _username = '',     //Login user name
        _authData = null,   //Response received from auth data service call
        _closebtn = null,   //The close button in YUI overlay
        _bVisible = false,  //Stores the current status of overlay if it is visible or not
        _user_role_info = null, //The YUI overlay object that has user role information
        _username_id = 'phedex-login-usrname'; //Used for positioning overlay while display

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
          var roleLen = _authData.role.length, indx = 0, overlayBody, role;
            if (roleLen > 0) {
                if (!_user_role_info) {
                    //Create a new YUI overlay to show user role information
                    _user_role_info = new Yw.Overlay("_user_role_info", { context: [_username_id, "tl", "bl", ["beforeShow", "windowResize"]], visible: false, width: "300px" });
                    log('The user role information YUI overlay is created', 'info', 'login');
                }
                else {
                    //Delete the previous YUI overlay body content
                    while (_user_role_info.body.hasChildNodes()) {
                        _user_role_info.body.removeChild(_user_role_info.body.lastChild);
                    }
                    log('The user role information YUI overlay body content is destroyed', 'info', 'login');
                }
                overlayBody = document.createElement('div');
                overlayBody.innerHTML = '<strong />Roles:</strong>';
                overlayBody.className = 'phedex-login-overlay-body';
                for (indx = 0; indx < roleLen; indx++) {
                    //Create rows in the table to fill user role information
                  role = _authData.role[indx];
                  overlayBody.innerHTML += '<br />' + role.name + ' of ' + role.group;

                }
                overlayBody.innerHTML += '<br />' + _logincomp.username.title;
                var closebtn = document.createElement('div');
                closebtn.id = 'phedex-login-info-close';
                overlayBody.appendChild(closebtn);
                _user_role_info.setBody(overlayBody);   //Fill the YUI overlay body with user role information table
                _user_role_info.render(document.body);  //Render the YUI overlay
                log('The user role information YUI overlay is rendered', 'info', 'login');
                //Create a button within YUI overlay to allow user to hide YUI overlay (on clicking the button)
                _closebtn = new Yw.Button({ label: "Close", id: "buttonClose", container: 'phedex-login-info-close', onclick: { fn: _closeOverlay} });
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
                _logincomp.username.title = ' logged in via certificate';
                _cur_state = 'usepassword';
                _updateLoginButton('Login with Password');
            }
            else if (_authData.state == 'passwd') { //Authentication done using password
                _logincomp.username.title = ' logged in via password';
                _cur_state = 'logout';
                YuD.addClass(_logincomp.btnsubmit, 'phedex-invisible');
                _updateLoginButton('Logout');
            }
            YuD.addClass(_logincomp.logininput, 'phedex-invisible'); //Hide the login input elements
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

    var _eventSuccess = new YuCE('login success'),
        _eventFailure = new YuCE('login failure');

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
            PHEDEX.Datasvc.Call({ method: 'post', api: 'auth', args: { SecModLogin: _username, SecModPwd: _pwd }, success_event: _eventSuccess, failure_event: _eventFailure });
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
        PHEDEX.Datasvc.Call({ method:'post', api:'auth', success_event:_eventSuccess, failure_event:_eventFailure });
    };

    /**
    * @method _resetLoginState
    * @description This resets the UI back to login mode i.e show user name and password text box
    * @private
    */
    var _resetLoginState = function() {
        YuD.removeClass(_logincomp.logininput, 'phedex-invisible'); //Show the login elements
        _logincomp.inputpwd.value = '';
        _logincomp.inputpwd.focus();
        if (!_logincomp.inputname.value) { _logincomp.inputname.focus(); }
        _logincomp.username.innerHTML = '';
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
        var logincomp = PxU.makeChild(divlogin, 'div', { id: 'phedex-nav-login', className: 'phedex-login' });
        logincomp.username = PxU.makeChild(logincomp, 'a', { className: 'phedex-login-username phedex-link' });
        logincomp.username.id = _username_id;
        logincomp.logininput = PxU.makeChild(logincomp, 'span', { className: 'phedex-invisible' });
//         var btnlogout = PxU.makeChild(logincomp, 'span');
        var labelname = PxU.makeChild(logincomp.logininput, 'span');
        labelname.innerHTML = 'User Name: ';
        logincomp.inputname = PxU.makeChild(logincomp.logininput, 'input', { type: 'text' });
        labelname = PxU.makeChild(logincomp.logininput, 'span');
        labelname.innerHTML = '&nbsp;Password: ';
        logincomp.inputpwd = PxU.makeChild(logincomp.logininput, 'input', { type: 'password' });
        logincomp.btnsubmit = PxU.makeChild(logincomp, 'span');
        YuE.addListener(logincomp.username, 'click', _showOverlay, this, true);
        var btnlogout = PxU.makeChild(logincomp, 'span');
        logincomp.objBtn = new Yw.Button({ label:'Login', id:'buttonOK', container:logincomp.btnsubmit, onclick:{ fn: _onLogin} });
        logincomp.objLogoutBtn = new Yw.Button({ label:'Logout', id:'buttonLogout', container:btnlogout, onclick:{ fn: _redirectPage} });
        _logincomp = logincomp;
        log('The login component is created', 'info', 'login');
    };

    /**
    * @method _redirectPage
    * @description This redirects the page to switch between HTTP and HTTPS.
    * @private
    */
    var _redirectPage = function() {
        var href = location.href;
        if (href.match(/http:/)) {
            href = href.replace(/^http:/, 'https:');
            href = href.replace(/:30002/, ':30004'); // this is a hack for developing code outside the CERN firewall
        }
        else if (href.match(/https:/)) {
            href = href.replace(/^https:/, 'http:');
            href = href.replace(/:30004/, ':30002'); // this is a hack for developing code outside the CERN firewall
        }
        window.location = href;
    }

    //Used to construct the login component.
    _construct = function() {
      return {
        me: 'login',
        id: 'login_'+PxU.Sequence(),

        /**
        * @method init
        * @description This creates the login component
        * @param {Object} args object specifies the 'el' element where login component should be built
        */
        init: function(args) {
          var el, uri=location.href, logincomp;
          if (typeof (args) == 'object') { el = args.el; }
          if (!el) { el = document.getElementById('phedex-login'); }
          if (uri.match(/^https:/)) {
            _initLoginComponent(el);
            _loginUsingCert();
          } else {
            logincomp = PxU.makeChild(el, 'div', { id: 'phedex-nav-login', className: 'phedex-login' }),
            objBtn = new Yw.Button({ label: 'Login', id: 'buttonLogin', container: logincomp, onclick: { fn: _redirectPage} });
          }
          this.selfHandler = function(obj) {
            return function(ev,arr) {
              var action = arr[0];
              switch (action) {
                case 'getAuth': {
//                   _sbx.notify(arr[1],'authData',_authData);
                  _sbx.notify('authData',_authData);
                  break;
                }
              }
            }
          }(this);
          _sbx.listen(this.me,this.selfHandler);
          _sbx.listen('InstanceChanged',this.reAuth);
        },
        reAuth: function() {
          if ( !_authData ) { return; }
          _authData = null;
          _loginUsingCert();
          _sbx.notify('authData',_authData);
//           if ( _cur_state == 'certlogin' ) { _loginUsingCert(); }
//           else { banner('changed instance while logged in with password!','error'); }
        }
      };
    }
    Yla(this, _construct(), true);
};
PHEDEX.Core.onLoaded('login');
log('loaded...','info','login');