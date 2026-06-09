User u = [SELECT Id, UserPreferencesUserDebugModePref FROM User WHERE Id = :UserInfo.getUserId()];
u.UserPreferencesUserDebugModePref = !u.UserPreferencesUserDebugModePref ?? true;
update u;
System.debug('Debug Mode enabled for ' + UserInfo.getUserName());