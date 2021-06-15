/*SQL Server patches contain program updates that fix security and product functionality issues found in the software. 
These patches can be installed with a security update, which is a single patch, or a cumulative update which is a group of patches. 
The SQL Server version and patch levels should be the most recent compatible with the organizations' operational needs.
*/

/* Dave Kawula -06/01/2021*/
/*
Ensure Latest SQL Server Cumulative and Security Updates are Installed
Check the value and if not at the current patch level get a plan to get updated
This could require and outage of production SQL so properly change control should be followed
*/

SELECT SERVERPROPERTY('ProductLevel') as SP_installed, SERVERPROPERTY('ProductVersion') as Version;



/* Ensure 'Ad Hoc Distributed Queries' Server Configuration Option is set to '0'
Surface Area Reduction - SQL Server offers various configuration options, some of them can be controlled by the `sp_configure` stored procedure. 
This section contains the listing of the corresponding recommendations.
*/

EXECUTE sp_configure 'show advanced options', 1;


/*Both value columns must show `0`.*/
SELECT name, CAST(value as int) as value_configured, CAST(value_in_use as int) as value_in_use 
FROM sys.configurations 
WHERE name = 'Ad Hoc Distributed Queries';

/*If value not 0 remediate with

EXECUTE sp_configure 'show advanced options', 1;
RECONFIGURE;
EXECUTE sp_configure 'Ad Hoc Distributed Queries', 0;
RECONFIGURE;
GO
EXECUTE sp_configure 'show advanced options', 0;
RECONFIGURE; 

*/

/*Ensure 'CLR Enabled' Server Configuration Option is set to '0'
Enabling use of CLR assemblies widens the attack surface of SQL Server and puts it at risk from both inadvertent and malicious assemblies.*/

SELECT name,
 CAST(value as int) as value_configured,
 CAST(value_in_use as int) as value_in_use
FROM sys.configurations
WHERE name = 'clr strict security';

/*If both values are `1`, this recommendation is Not Applicable. Otherwise, run the following T-SQL command: */

SELECT name,
 CAST(value as int) as value_configured,
 CAST(value_in_use as int) as value_in_use
FROM sys.configurations
WHERE name = 'clr enabled';

/*Both value columns must show `0` to be compliant.*/

/*To fix this run

EXECUTE sp_configure 'clr enabled', 0;
RECONFIGURE;

*/


/*Ensure 'Cross DB Ownership Chaining' Server Configuration Option is set to '0'

The `cross db ownership chaining` option controls cross-database ownership chaining across all databases at the instance (or server) level.
When enabled, this option allows a member of the `db_owner` role in a database to gain access to objects owned by a login in any other database, 
causing an unnecessary information disclosure. When required, cross-database ownership chaining should only be enabled for the specific databases
requiring it instead of at the instance level for all databases by using the `ALTER DATABASE`_`<database_name>`_`SET DB_CHAINING ON` command. 
This database option may not be changed on the `master`, `model`, or `tempdb` system databases.
*/

SELECT name,
 CAST(value as int) as value_configured,
 CAST(value_in_use as int) as value_in_use
FROM sys.configurations
WHERE name = 'cross db ownership chaining';

/*Both value columns must show `0` to be compliant.*/

/*To Remediate
EXECUTE sp_configure 'cross db ownership chaining', 0;
RECONFIGURE;
GO 
*/



/*Ensure 'Database Mail XPs' Server Configuration Option is set to '0'

The `Database Mail XPs` option controls the ability to generate and transmit email messages from SQL Server.
Disabling the `Database Mail XPs` option reduces the SQL Server surface, eliminates a DOS attack vector and channel to exfiltrate data from the database server to a remote host.
*/

SELECT name,
 CAST(value as int) as value_configured,
 CAST(value_in_use as int) as value_in_use
FROM sys.configurations
WHERE name = 'Database Mail XPs';

/*Both value columns must show `0` to be compliant.*/

/*Remediation

EXECUTE sp_configure 'show advanced options', 1;
RECONFIGURE;
EXECUTE sp_configure 'Database Mail XPs', 0;
RECONFIGURE;
GO
EXECUTE sp_configure 'show advanced options', 0;
RECONFIGURE;

*/

/* Ensure 'Ole Automation Procedures' Server Configuration Option is set to '0'

The `Ole Automation Procedures` option controls whether OLE Automation objects can be instantiated within Transact-SQL batches. 
These are extended stored procedures that allow SQL Server users to execute functions external to SQL Server.

Enabling this option will increase the attack surface of SQL Server and allow users to execute functions in the security context of SQL Server.

*/

SELECT name, 
 CAST(value as int) as value_configured, 
 CAST(value_in_use as int) as value_in_use 
FROM sys.configurations 
WHERE name = 'Ole Automation Procedures'; 



/*Both value columns must show `0` to be compliant.*/

/*Remediation

EXECUTE sp_configure 'show advanced options', 1;
RECONFIGURE;
EXECUTE sp_configure 'Ole Automation Procedures', 0;
RECONFIGURE;
GO
EXECUTE sp_configure 'show advanced options', 0;
RECONFIGURE;


*/



/*Ensure 'Remote Access' Server Configuration Option is set to '0'

The `remote access` option controls the execution of local stored procedures on remote servers or remote stored procedures on local server.
The Dedicated Administrator Connection (DAC) lets an administrator access a running server to execute diagnostic functions or Transact-SQL statements, 
or to troubleshoot problems on the server, even when the server is locked or running in an abnormal state and not responding to a SQL Server Database Engine connection. 
In a cluster scenario, the administrator may not actually be logged on to the same node that is currently hosting the SQL Server instance and thus is considered "remote". 
Therefore, this setting should usually be enabled (`1`) for SQL Server failover clusters; otherwise, it should be disabled (`0`) which is the default.

*/

USE master;
GO
SELECT name, 
 CAST(value as int) as value_configured,
 CAST(value_in_use as int) as value_in_use
FROM sys.configurations
WHERE name = 'remote admin connections'
AND SERVERPROPERTY('IsClustered') = 0;


/*If no data is returned, the instance is a cluster and this recommendation is not applicable. If data is returned, then both the value columns must show `0` to be compliant.*/

/*Remediation 


EXECUTE sp_configure 'remote admin connections', 0;
RECONFIGURE;
GO

*/




/*Ensure 'Scan For Startup Procs' Server Configuration Option is set to '0'

The `scan for startup procs` option, if enabled, causes SQL Server to scan for and automatically run all stored procedures that are set to execute upon service startup.
Enforcing this control reduces the threat of an entity leveraging these facilities for malicious purposes.
*/

SELECT name,
 CAST(value as int) as value_configured,
 CAST(value_in_use as int) as value_in_use
FROM sys.configurations
WHERE name = 'scan for startup procs';

/*Both value columns must show `0`.*/

/*Remediation

EXECUTE sp_configure 'show advanced options', 1;
RECONFIGURE;
EXECUTE sp_configure 'scan for startup procs', 0;
RECONFIGURE;
GO
EXECUTE sp_configure 'show advanced options', 0;
RECONFIGURE;

/*Restart the Database Engine.*/

*/


/*Ensure 'Trustworthy' Database Property is set to 'Off'

The `TRUSTWORTHY` database option allows database objects to access objects in other databases under certain circumstances.
Provides protection from malicious CLR assemblies or extended procedures.
*/

/*Run the following T-SQL query to list any databases with a Trustworthy database property value of `ON`:*/

SELECT name
FROM sys.databases
WHERE is_trustworthy_on = 1
AND name != 'msdb';

/*No rows should be returned.*/

/*Remediation*/

/*Execute the following T-SQL statement against the databases (replace _`<database_name>`_ below) returned by the Audit Procedure:

ALTER DATABASE [<database_name>] SET TRUSTWORTHY OFF;

*/


/*Ensure Unnecessary SQL Server Protocols are set to 'Disabled'

SQL Server supports Shared Memory, Named Pipes, and TCP/IP protocols. However, SQL Server should be configured to use the bare minimum required based on the organization's needs.
Using fewer protocols minimizes the attack surface of SQL Server and, in some cases, can protect it from remote attacks.
Open **SQL Server Configuration Manager**; go to the **SQL Server Network Configuration**. Ensure that only required protocols are enabled.
Open **SQL Server Configuration Manager**; go to the **SQL Server Network Configuration**. Ensure that only required protocols are enabled. Disable protocols not necessary.
*/



/*Ensure SQL Server is configured to use non-standard ports

If installed, a default SQL Server instance will be assigned a default port of `TCP:1433` for TCP/IP communication. 
Administrators can also manually configure named instances to use `TCP:1433` for communication.
`TCP:1433` is a widely known SQL Server port and this port assignment should be changed. In a multi-instance scenario, each instance must be assigned its own dedicated TCP/IP port.
Using a non-default port helps protect the database from attacks directed to the default port.
*/

SELECT TOP(1) local_tcp_port FROM sys.dm_exec_connections
WHERE local_tcp_port IS NOT NULL;

/*Or*/

SELECT local_tcp_port
FROM sys.dm_exec_connections
WHERE session_id = @@SPID

/*If a value of `1433` is returned this is a fail.*/


/*Remediation

1. In **SQL Server Configuration Manager**, in the console pane, expand **SQL Server Network Configuration**, expand Protocols for _`<InstanceName>`_, and then double-click the TCP/IP protocol
2. In the **TCP/IP Properties** dialog box, on the **IP Addresses** tab, several IP addresses appear in the format `IP1`, `IP2`, up to `IPAll`. One of these is for the IP address of the loopback adapter, `127.0.0.1`. Additional IP addresses appear for each IP Address on the computer.
3. Under `IPAll`, change the **TCP Port** field from `1433` to a non-standard port or leave the **TCP Port** field empty and set the **TCP Dynamic Ports** value to `0` to enable dynamic port assignment and then click **OK**.
4. In the console pane, click **SQL Server Services**.
5. In the details pane, right-click **SQL Server (_\<InstanceName\>_)** and then click **Restart**, to stop and restart SQL Server.

*/



/*Ensure 'Hide Instance' option is set to 'Yes' for Production SQL Server instances

Non-clustered SQL Server instances within production environments should be designated as hidden to prevent advertisement by the SQL Server Browser service.

Designating production SQL Server instances as hidden leads to a more secure installation because they cannot be enumerated. However, clustered instances may break if this option is selected.

Perform either the GUI or T-SQL method shown:
#### GUI Method
1. In **SQL Server Configuration Manager**, expand **SQL Server Network Configuration**, right-click **Protocols for _\<InstanceName\>_**, and then select **Properties**.
2. On the **Flags** tab, in the **Hide Instance** box, if `Yes` is selected, it is compliant.

*/

DECLARE @getValue INT;
EXEC master.sys.xp_instance_regread
 @rootkey = N'HKEY_LOCAL_MACHINE',
 @key = N'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQLServer\SuperSocketNetLib',
 @value_name = N'HideInstance',
 @value = @getValue OUTPUT;
SELECT @getValue;

/*A value of `1` should be returned to be compliant.*/

/*Remediation

Perform either the GUI or T-SQL method shown:
#### GUI Method
1. In **SQL Server Configuration Manager**, expand **SQL Server Network Configuration**, right-click **Protocols for _\<InstanceName\>_**, and then select **Properties**.
2. On the **Flags** tab, in the **Hide Instance** box, select `Yes`, and then click **OK** to close the dialog box. The change takes effect immediately for new connections.

EXEC master.sys.xp_instance_regwrite
 @rootkey = N'HKEY_LOCAL_MACHINE',
 @key = N'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQLServer\SuperSocketNetLib',
 @value_name = N'HideInstance',
 @type = N'REG_DWORD',
 @value = 1;

 */


 /*Ensure the 'sa' Login Account is set to 'Disabled'
 
 The `sa` account is a widely known and often widely used SQL Server account with sysadmin privileges. This is the original login created during installation and always has the `principal_id=1` and `sid=0x01`.
 Enforcing this control reduces the probability of an attacker executing brute force attacks against a well-known principal.

  Use the following syntax to determine if the `sa` account is disabled. Checking for `sid=0x01` ensures that the original `sa` account is being checked in case it has been renamed per best practices. 
*/

SELECT name, is_disabled
FROM sys.server_principals
WHERE sid = 0x01
AND is_disabled = 0;


/*No rows should be returned to be compliant. 
An `is_disabled` value of `0` indicates the login is currently enabled and therefore needs remediation.*/

/*Remediation


USE [master]
GO
DECLARE @tsql nvarchar(max)
SET @tsql = 'ALTER LOGIN ' + SUSER_NAME(0x01) + ' DISABLE'
EXEC (@tsql)
GO
*/

/*Ensure the 'sa' Login Account has been renamed

The `sa` account is a widely known and often widely used SQL Server login with sysadmin privileges. 
The `sa` login is the original login created during installation and always has `principal_id=1` and `sid=0x01`.
It is more difficult to launch password-guessing and brute-force attacks against the `sa` login if the name is not known.

Use the following syntax to determine if the `sa` login (principal) is renamed.
*/


SELECT name
FROM sys.server_principals
WHERE sid = 0x01;


/*A name of `sa` indicates the account has not been renamed and therefore needs remediation.*/

/*Remediation

Replace the _`<different_user>`_ value within the below syntax and execute to rename the `sa` login.


ALTER LOGIN sa WITH NAME = Jupiter;
*/

/*Ensure 'AUTO_CLOSE' is set to 'OFF' on contained databases

`AUTO_CLOSE` determines if a given database is closed or not after a connection terminates. 
If enabled, subsequent connections to the given database will require the database to be reopened and relevant procedure caches to be rebuilt.

Because authentication of users for contained databases occurs within the database not at the server\instance level, 
the database must be opened every time to authenticate a user. The frequent opening/closing of the database consumes 
additional server resources and may contribute to a denial of service.

Perform the following to find contained databases that are not configured as prescribed:
*/

SELECT name, containment, containment_desc, is_auto_close_on
FROM sys.databases
WHERE containment <> 0 and is_auto_close_on = 1;

/*No rows should be returned.*/

/*Remediation
Execute the following T-SQL, replacing _`<database_name>`_ with each database name found by the Audit Procedure:

ALTER DATABASE <database_name> SET AUTO_CLOSE OFF;
*/


/*Ensure no login exists with the name 'sa'

The `sa` login (e.g. principal) is a widely known and often widely used SQL Server account. 
Therefore, there should not be a login called `sa` even when the original `sa` login (`principal_id = 1`) has been renamed.
Enforcing this control reduces the probability of an attacker executing brute force attacks against a well-known principal name.

Use the following syntax to determine if there is an account named `sa`.
*/
SELECT principal_id, name
FROM sys.server_principals
WHERE name = 'sa';

/*No rows should be returned.*/

/*Remediation
Execute the appropriate `ALTER` or `DROP` statement below based on the `principal_id` returned for the login named `sa`.
Replace the _`<different_name>`_ value within the below syntax and execute to rename the `sa` login.

USE [master]
GO
-- If principal_id = 1 or the login owns database objects, rename the sa login 
ALTER LOGIN [sa] WITH NAME = <different_name>;
GO
-- If the login owns no database objects, then drop it 
-- Do NOT drop the login if it is principal_id = 1
DROP LOGIN sa
*/



/*Ensure 'clr strict security' Server Configuration Option is set to '1'

The `clr strict security` option specifies whether the engine applies the `PERMISSION_SET` on the assemblies.
Enabling use of CLR assemblies widens the attack surface of SQL Server and puts it at risk from both inadvertent and malicious assemblies.

*/

SELECT name,
 CAST(value as int) as value_configured,
 CAST(value_in_use as int) as value_in_use
FROM sys.configurations
WHERE name = 'clr strict security';

/*Both value columns must show `1` to be compliant.*/

/*Remediation

EXECUTE sp_configure 'show advanced options', 1;
RECONFIGURE;
EXECUTE sp_configure 'clr strict security', 1;
RECONFIGURE;
GO
EXECUTE sp_configure 'show advanced options', 0;
RECONFIGURE;

*/


/*Ensure 'Server Authentication' Property is set to 'Windows Authentication Mode'

Uses **Windows Authentication** to validate attempted connections.
Windows provides a more robust authentication mechanism than SQL Server authentication.

*/

SELECT SERVERPROPERTY('IsIntegratedSecurityOnly') as [login_mode];

/*A `login_mode` of `1` indicates the **Server Authentication** property is set to **Windows Authentication Mode**. A `login_mode` of `0` indicates mixed mode authentication.*/

/*Remediation

Perform either the GUI or T-SQL method shown:
#### GUI Method
1. Open **SQL Server Management Studio**.
2. Open the **Object Explorer** tab and connect to the target database instance.
3. Right click the instance name and select **Properties**.
4. Select the **Security** page from the left menu.
5. Set the **Server authentication** setting to **Windows Authentication Mode**.

#### T-SQL Method

USE [master]
GO
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', REG_DWORD, 1
GO

/*Restart the SQL Server service for the change to take effect.*/

*/

/*Ensure CONNECT permissions on the 'guest' user is Revoked within all SQL Server databases excluding the master, msdb and tempdb

Remove the right of the `guest` user to connect to SQL Server databases, except for `master`, `msdb`, and `tempdb`.
A login assumes the identity of the `guest` user when a login has access to SQL Server but does not have access to a database through
its own account and the database has a `guest` user account. Revoking the `CONNECT` permission for the `guest` user will ensure that 
a login is not able to access database information without explicit access to do so.

Run the following code snippet for each database (replacing _`<database_name>`_ as appropriate) in the instance to determine if the `guest` user has `CONNECT` permission. No rows should be returned.
*/
USE SolarWindsOrion;
GO
SELECT DB_NAME() AS DatabaseName, 'guest' AS Database_User, [permission_name], [state_desc]
FROM sys.database_permissions 
WHERE [grantee_principal_id] = DATABASE_PRINCIPAL_ID('guest') 
AND [state_desc] LIKE 'GRANT%' 
AND [permission_name] = 'CONNECT'
AND DB_NAME() NOT IN ('master','tempdb','msdb');


/*The following code snippet revokes `CONNECT` permissions from the `guest` user in a database. Replace _`<database_name>`_ as appropriate:*/
/*
USE <database_name>;
GO
REVOKE CONNECT FROM guest;

*/

/*Ensure 'Orphaned Users' are Dropped From SQL Server Databases

A database user for which the corresponding SQL Server login is undefined or is incorrectly defined on a server instance cannot log in to the
instance and is referred to as orphaned and should be removed.

Orphan users should be removed to avoid potential misuse of those broken users in any way.

Run the following T-SQL query in each database to identify orphan users. No rows should be returned.
*/
USE SolarWindsOrion;
GO
EXEC sp_change_users_login @Action='Report';


/*If the orphaned user cannot or should not be matched to an existing or new login using the Microsoft documented process 
referenced below, run the following T-SQL query in the appropriate database to remove an orphan user:

USE <database_name>;
GO
DROP USER <username>;
*/


/*Ensure SQL Authentication is not used in contained databases
Contained databases do not enforce password complexity rules for SQL Authenticated users.
The absence of an enforced password policy may increase the likelihood of a weak credential being established in a contained database.

Execute the following T-SQL in each contained database to find database users that are using SQL authentication:
*/
SELECT name AS DBUser
FROM sys.database_principals
WHERE name NOT IN ('dbo','Information_Schema','sys','guest')
AND type IN ('U','S','G')
AND authentication_type = 2;
GO

/*Leverage Windows Authenticated users in contained databases.*/



/*Ensure the SQL Server’s MSSQL Service Account is Not an Administrator
The service account and/or service SID used by the `MSSQLSERVER` service for a default instance or _`<InstanceName>`_ 
service for a named instance should not be a member of the Windows Administrator group either directly or indirectly (via a group). 
This also means that the account known as `LocalSystem` (aka `NT AUTHORITY\SYSTEM`) should not be used for the `MSSQL` service as 
this account has higher privileges than the SQL Server service requires.

Following the principle of least privilege, the service account should have no more privileges than required to do its job. 
For SQL Server services, the SQL Server Setup will assign the required permissions directly to the service `SID`. 
No additional permissions or privileges should be necessary.

Verify that the service account (in case of a local or AD account) and service `SID` are not members of the Windows Administrators group.

In the case where `LocalSystem` is used, use **SQL Server Configuration Manager** to change to a less privileged account. Otherwise, 
remove the account or service `SID` from the Administrators group. You may need to run the **SQL Server Configuration Manager** 
if underlying permissions had been changed or if **SQL Server Configuration Manager** was not originally used to set the service account.

*/



/*Ensure the SQL Server’s SQLAgent Service Account is Not an Administrator

The service account and/or service `SID` used by the `SQLSERVERAGENT` service for a default instance or `SQLAGENT$`_`<InstanceName>`_ 
service for a named instance should not be a member of the Windows Administrator group either directly or indirectly (via a group).
This also means that the account known as `LocalSystem` (AKA `NT AUTHORITY\SYSTEM`) should not be used for the `SQLAGENT` service
as this account has higher privileges than the SQL Server service requires.

Following the principle of least privilege, the service account should have no more privileges than required to do its job.
For SQL Server services, the SQL Server Setup will assign the required permissions directly to the service `SID`. 
No additional permissions or privileges should be necessary.

Verify that the service account (in case of a local or AD account) and service `SID` are not members of the Windows Administrators group.

In the case where `LocalSystem` is used, use **SQL Server Configuration Manager** to change to a less privileged account.
Otherwise, remove the account or service `SID` from the Administrators group. You may need to run the **SQL Server Configuration Manager** 3
if underlying permissions had been changed or if **SQL Server Configuration Manager** was not originally used to set the service account.

*/




/*Ensure the SQL Server’s Full-Text Service Account is Not an Administrator
The service account and/or service `SID` used by the `MSSQLFDLauncher` service for a default instance or `MSSQLFDLauncher$`_`<InstanceName>`_ 
service for a named instance should not be a member of the Windows Administrator group either directly or indirectly (via a group). 
This also means that the account known as `LocalSystem` (aka `NT AUTHORITY\SYSTEM`) should not be used for the Full-Text service as this 
account has higher privileges than the SQL Server service requires.

Following the principle of least privilege, the service account should have no more privileges than required to do its job. 
For SQL Server services, the SQL Server Setup will assign the required permissions directly to the service `SID`. No additional
permissions or privileges should be necessary.

Verify that the service account (in case of a local or AD account) and service `SID` are not members of the Windows Administrators group.

In the case where `LocalSystem` is used, use **SQL Server Configuration Manager** to change to a less privileged account. 
Otherwise, remove the account or service `SID` from the Administrators group. You may need to run the **SQL Server Configuration Manager**
if underlying permissions had been changed or if **SQL Server Configuration Manager** was not originally used to set the service account.

*/



/*Ensure only the default permissions specified by Microsoft are granted to the public server role

`public` is a special fixed server role containing all logins. Unlike other fixed server roles, permissions can be changed for the `public` role.
In keeping with the principle of least privileges, the `public` server role should not be used to grant permissions at the server scope as these would be inherited by all users.

Every SQL Server login belongs to the `public` role and cannot be removed from this role. Therefore, any permissions granted to this role will be
available to all logins unless they have been explicitly denied to specific logins or user-defined server roles.

Use the following syntax to determine if extra permissions have been granted to the `public` server role.
*/

SELECT * 
FROM master.sys.server_permissions
WHERE (grantee_principal_id = SUSER_SID(N'public') and state_desc LIKE 'GRANT%')
AND NOT (state_desc = 'GRANT' and [permission_name] = 'VIEW ANY DATABASE' and class_desc = 'SERVER')
AND NOT (state_desc = 'GRANT' and [permission_name] = 'CONNECT' and class_desc = 'ENDPOINT' and major_id = 2)
AND NOT (state_desc = 'GRANT' and [permission_name] = 'CONNECT' and class_desc = 'ENDPOINT' and major_id = 3)
AND NOT (state_desc = 'GRANT' and [permission_name] = 'CONNECT' and class_desc = 'ENDPOINT' and major_id = 4)
AND NOT (state_desc = 'GRANT' and [permission_name] = 'CONNECT' and class_desc = 'ENDPOINT' and major_id = 5);

/*This query should not return any rows.*/

/*Add the extraneous permissions found in the Audit query results to the specific logins to user-defined server roles which require the access. 
Revoke the _`<permission_name>`_ from the `public` role as shown below
 
 USE [master]
 GO
 REVOKE <permission_name> FROM public;
 GO
 
 */

 /*Ensure Windows BUILTIN groups are not SQL Logins

Prior to SQL Server 2008, the `BUILTIN\Administrators` group was added as a SQL Server login with sysadmin privileges during installation by default.
Best practices promote creating an Active Directory level group containing approved DBA staff accounts and using this controlled AD group as the 
login with sysadmin privileges. The AD group should be specified during SQL Server installation and the `BUILTIN\Administrators` 
group would therefore have no need to be a login.

The `BUILTIN` groups (Administrators, Everyone, Authenticated Users, Guests, etc.) generally contain very broad memberships which would not meet
the best practice of ensuring only the necessary users have been granted access to a SQL Server instance. These groups should not be used for any
level of access into a SQL Server Database Engine instance.

Use the following syntax to determine if any `BUILTIN` groups or accounts have been added as SQL Server Logins.

*/
SELECT pr.[name], pe.[permission_name], pe.[state_desc]
FROM sys.server_principals pr
JOIN sys.server_permissions pe
ON pr.principal_id = pe.grantee_principal_id
WHERE pr.name like 'BUILTIN%';

/*This query should not return any rows.*/

/*

1. For each `BUILTIN` login, if needed create a more restrictive AD group containing only the required user accounts. 
2. Add the AD group or individual Windows accounts as a SQL Server login and grant it the permissions required. 
3. Drop the `BUILTIN` login using the syntax below after replacing _`<name>`_ in `[BUILTIN\`_`<name>`_`]`.
 ```
 USE [master]
 GO
 DROP LOGIN [BUILTIN\<name>]
 GO
 ```

 */


 /*Ensure Windows local groups are not SQL Logins

 Local Windows groups should not be used as logins for SQL Server instances.
 Allowing local Windows groups as SQL Logins provides a loophole whereby anyone with OS level administrator rights 
 (and no SQL Server rights) could add users to the local Windows groups and thereby give themselves or others access to the SQL Server instance.

 Use the following syntax to determine if any local groups have been added as SQL Server Logins.
*/
USE [master]
GO
SELECT pr.[name] AS LocalGroupName, pe.[permission_name], pe.[state_desc]
FROM sys.server_principals pr
JOIN sys.server_permissions pe
ON pr.[principal_id] = pe.[grantee_principal_id]
WHERE pr.[type_desc] = 'WINDOWS_GROUP'
AND pr.[name] like CAST(SERVERPROPERTY('MachineName') AS nvarchar) + '%';

/*This query should not return any rows.*/


/*
1. For each `LocalGroupName` login, if needed create an equivalent AD group containing only the required user accounts. 
2. Add the AD group or individual Windows accounts as a SQL Server login and grant it the permissions required. 
3. Drop the `LocalGroupName` login using the syntax below after replacing _`<name>`_.
 ```
 USE [master]
 GO
 DROP LOGIN [<name>]
 GO
 ```

 */



 /*Ensure the public role in the msdb database is not granted access to SQL Agent proxies

 The `public` database role contains every user in the `msdb` database. SQL Agent proxies define a security context in which a job step can run.
 Granting access to SQL Agent proxies for the `public` role would allow all users to utilize the proxy which may have high privileges. This would likely break the principle of least privileges.

 Use the following syntax to determine if access to any proxies have been granted to the `msdb` database's `public` role.
*/
USE [msdb]
GO
SELECT sp.name AS proxyname
FROM dbo.sysproxylogin spl
JOIN sys.database_principals dp
ON dp.sid = spl.sid
JOIN sysproxies sp
ON sp.proxy_id = spl.proxy_id
WHERE principal_id = USER_ID('public');
GO

/*This query should not return any rows.*/

/*

1. Ensure the required security principals are explicitly granted access to the proxy (use `sp_grant_login_to_proxy`).
2. Revoke access to the _`<proxyname>`_ from the `public` role.
 ```
 USE [msdb]
 GO
 EXEC dbo.sp_revoke_login_from_proxy @name = N'public', @proxy_name = N'<proxyname>';
 GO
 ```

 */


 /*Ensure 'MUST_CHANGE' Option is set to 'ON' for All SQL Authenticated Logins
 Whenever this option is set to `ON`, SQL Server will prompt for an updated password the first time the new or altered login is used.
Enforcing a password change after a reset or new login creation will prevent the account administrators or anyone accessing the initial password from misuse of the SQL login created without being noticed.

1. Open **SQL Server Management Studio**.
2. Open **Object Explorer** and connect to the target instance.
3. Navigate to the **Logins** tab in **Object Explorer** and expand. Right click on the desired login and select **Properties**.
4. Verify the User must change password at next login checkbox is checked.

**Note:** This audit procedure is only applicable immediately after the login has been created or altered to force the password change. Once the password is changed, there is no way to know specifically that this option was the forcing mechanism behind a password change.

Set the `MUST_CHANGE` option for SQL Authenticated logins when creating a login initially:
```
CREATE LOGIN <login_name> WITH PASSWORD = '<password_value>' MUST_CHANGE, CHECK_EXPIRATION = ON, CHECK_POLICY = ON;
```

Set the `MUST_CHANGE` option for SQL Authenticated logins when resetting a password: 
```
ALTER LOGIN <login_name> WITH PASSWORD = '<new_password_value>' MUST_CHANGE;
```

*/



/*Ensure 'CHECK_EXPIRATION' Option is set to 'ON' for All SQL Authenticated Logins Within the Sysadmin Role
Applies the same password expiration policy used in Windows to passwords used inside SQL Server.
Ensuring SQL logins comply with the secure password policy applied by the Windows Server Benchmark will ensure the passwords for 
SQL logins with `sysadmin` privileges are changed on a frequent basis to help prevent compromise via a brute force attack.
`CONTROL SERVER` is an equivalent permission to `sysadmin` and logins with that permission should also be required to have expiring passwords.

Run the following T-SQL statement to find `sysadmin` or equivalent logins with `CHECK_EXPIRATION = OFF`. No rows should be returned.
*/


SELECT l.[name], 'sysadmin membership' AS 'Access_Method'
FROM sys.sql_logins AS l
WHERE IS_SRVROLEMEMBER('sysadmin',name) = 1
AND l.is_expiration_checked <> 1
UNION ALL
SELECT l.[name], 'CONTROL SERVER' AS 'Access_Method'
FROM sys.sql_logins AS l
JOIN sys.server_permissions AS p
ON l.principal_id = p.grantee_principal_id
WHERE p.type = 'CL' AND p.state IN ('G', 'W')
AND l.is_expiration_checked <> 1;

/*
For each _`<login_name>`_ found by the Audit Procedure, execute the following T-SQL statement: 
```
ALTER LOGIN [<login_name>] WITH CHECK_EXPIRATION = ON;
```

*/


/*Ensure 'CHECK_POLICY' Option is set to 'ON' for All SQL Authenticated Logins

Applies the same password complexity policy used in Windows to passwords used inside SQL Server.

Ensure SQL authenticated login passwords comply with the secure password policy applied by the Windows
Server Benchmark so that they cannot be easily compromised via brute force attack.

Use the following code snippet to determine the status of SQL Logins and if their password complexity is enforced.
*/
SELECT name, is_disabled
FROM sys.sql_logins
WHERE is_policy_checked = 0;

/*
The `is_policy_checked` value of `0` indicates that the `CHECK_POLICY` option is `OFF`; value of `1` is `ON`. If `is_disabled` 
value is `1`, then the login is disabled and unusable. If no rows are returned then either no SQL Authenticated logins exist or they all have `CHECK_POLICY` `ON`.

*/


/*For each _`<login_name>`_ found by the Audit Procedure, execute the following T-SQL statement:
```
ALTER LOGIN [<login_name>] WITH CHECK_POLICY = ON;
```

**Note:** In the case of AWS RDS do not perform this remediation for the Master account.v

*/



/*Ensure 'Maximum number of error log files' is set to greater than or equal to '12'

SQL Server error log files must be protected from loss. The log files must be backed up before they are overwritten. 
Retaining more error logs helps prevent loss from frequent recycling before backups can occur.

The SQL Server error log contains important information about major server events and login attempt information as well.

Perform either the GUI or T-SQL method shown:
#### GUI Method
1. Open **SQL Server Management Studio**.
2. Open **Object Explorer** and connect to the target instance.
3. Navigate to the **Management** tab in **Object Explorer** and expand. Right click on the **SQL Server Logs** file and select **Configure**.
4. Verify the **Limit the number of error log files before they are recycled** checkbox is checked
5. Verify the **Maximum number of error log files** is greater than or equal to `12`
#### T-SQL Method
Run the following T-SQL. The `NumberOfLogFiles` returned should be greater than or equal to `12`.
```

*/
DECLARE @NumErrorLogs int;
EXEC master.sys.xp_instance_regread
N'HKEY_LOCAL_MACHINE',
N'Software\Microsoft\MSSQLServer\MSSQLServer',
N'NumErrorLogs',
@NumErrorLogs OUTPUT;
SELECT ISNULL(@NumErrorLogs, -1) AS [NumberOfLogFiles];
/*
Adjust the number of logs to prevent data loss. The default value of `6` may be insufficient for a production environment. Perform either the GUI or T-SQL method shown:
#### GUI Method
1. Open **SQL Server Management Studio**.
2. Open **Object Explorer** and connect to the target instance.
3. Navigate to the **Management** tab in **Object Explorer** and expand. Right click on the **SQL Server Logs** file and select **Configure**
4. Check the **Limit the number of error log files before they are recycled**
5. Set the **Maximum number of error log files** to greater than or equal to `12`
#### T-SQL Method
Run the following T-SQL to change the number of error log files, replace _`<NumberAbove12>`_ with your desired number of error log files:

EXEC master.sys.xp_instance_regwrite
N'HKEY_LOCAL_MACHINE',
N'Software\Microsoft\MSSQLServer\MSSQLServer',
N'NumErrorLogs',
REG_DWORD,
<NumberAbove12>;
*/



/*Ensure 'Default Trace Enabled' Server Configuration Option is set to '1'
The default trace provides audit logging of database activity including account creations, privilege elevation and execution of DBCC commands.
Default trace provides valuable audit information regarding security-related activities on the server.

Run the following T-SQL command:
*/
SELECT name,
 CAST(value as int) as value_configured,
 CAST(value_in_use as int) as value_in_use
FROM sys.configurations
WHERE name = 'default trace enabled';

/*Both value columns must show `1`.*/

/*
Run the following T-SQL command:
```
EXECUTE sp_configure 'show advanced options', 1;
RECONFIGURE;
EXECUTE sp_configure 'default trace enabled', 1;
RECONFIGURE;
GO
EXECUTE sp_configure 'show advanced options', 0;
RECONFIGURE;
```
*/




/*Ensure 'Login Auditing' is set to 'failed logins'
This setting will record failed authentication attempts for SQL Server logins to the **SQL Server Errorlog**. This is the default setting for SQL Server. 

Historically, this setting has been available in all versions and editions of SQL Server. Prior to the availability of 
**SQL Server Audit**, this was the only provided mechanism for capturing logins (successful or failed).

Capturing failed logins provides key information that can be used to detect\confirm password guessing attacks. Capturing successful login attempts can be
used to confirm server access during forensic investigations, but using this audit level setting to also capture successful logins creates excessive
noise in the **SQL Server Errorlog** which can hamper a DBA trying to troubleshoot problems. Elsewhere in this benchmark, we recommend using the newer
lightweight SQL Server Audit feature to capture both successful and failed logins.


*/
EXEC xp_loginconfig 'audit level'; 

/*
A `config_value` of `failure` indicates a server login auditing setting of **Failed logins only**. If a `config_value` of `all` appears, 
then both failed and successful logins are being logged. Both settings should also be considered valid, but as mentioned capturing successful 
logins using this method creates lots of noise in the **SQL Server Errorlog**.

*/
/*
Perform either the GUI or T-SQL method shown:
#### GUI Method
1. Open **SQL Server Management Studio**.
2. Right click the target instance and select **Properties** and navigate to the **Security** tab.
3. Select the option **Failed logins only** under the **Login Auditing** section and click **OK**.
4. Restart the SQL Server instance.

#### T-SQL Method
1. Run: 
 ```
 EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'AuditLevel', REG_DWORD, 2
 ```
2. Restart the SQL Server instance.

*/


/*Ensure 'SQL Server Audit' is set to capture both 'failed' and 'successful logins'

SQL Server Audit is capable of capturing both failed and successful logins and writing them to one of three places: the application event log,
the security event log, or the file system. We will use it to capture any login attempt to SQL Server, as well as any attempts to change audit policy.
This will also serve to be a second source to record failed login attempts.

By utilizing Audit instead of the traditional setting under the Security tab to capture successful logins, we reduce the noise in the `ERRORLOG`. 
This keeps it smaller and easier to read for DBAs who are attempting to troubleshoot issues with the SQL Server. Also, the Audit object can write to
the security event log, though this requires operating system configuration. This gives an additional option for where to store login events, especially 
in conjunction with an SIEM.
*/

SELECT 
 S.name AS 'Audit Name'
 , CASE S.is_state_enabled
 WHEN 1 THEN 'Y'
 WHEN 0 THEN 'N' END AS 'Audit Enabled'
 , S.type_desc AS 'Write Location'
 , SA.name AS 'Audit Specification Name'
 , CASE SA.is_state_enabled
 WHEN 1 THEN 'Y'
 WHEN 0 THEN 'N' END AS 'Audit Specification Enabled'
 , SAD.audit_action_name
 , SAD.audited_result
FROM sys.server_audit_specification_details AS SAD
 JOIN sys.server_audit_specifications AS SA
 ON SAD.server_specification_id = SA.server_specification_id
 JOIN sys.server_audits AS S
 ON SA.audit_guid = S.audit_guid
WHERE SAD.audit_action_id IN ('CNAU', 'LGFL', 'LGSD');

/*
The result set should contain 3 rows, one for each of the following `audit_action_names`:

- `AUDIT_CHANGE_GROUP`
- `FAILED_LOGIN_GROUP`
- `SUCCESSFUL_LOGIN_GROUP`

Both the Audit and Audit specification should be enabled and the `audited_result` should include both success and failure.

*/

/*
Perform either the GUI or T-SQL method shown:
#### GUI Method
1. Expand the **SQL Server** in **Object Explorer**.
2. Expand the **Security Folder**
3. Right-click on the **Audits** folder and choose **New Audit...**
4. Specify a name for the **Server Audit**.
5. Specify the audit destination details and then click **OK** to save the **Server Audit**.
6. Right-click on **Server Audit Specifications** and choose **New Server Audit Specification...**
7. Name the **Server Audit Specification**
8. Select the just created **Server Audit** in the **Audit** drop-down selection.
9. Click the drop-down under **Audit Action Type** and select `AUDIT_CHANGE_GROUP`.
10. Click the new drop-down **Audit Action Type** and select `FAILED_LOGIN_GROUP`.
11. Click the new drop-down under **Audit Action Type** and select `SUCCESSFUL_LOGIN_GROUP`.
12. Click OK to save the **Server Audit Specification**.
13. Right-click on the new **Server Audit Specification** and select **Enable Server Audit Specification**.
14. Right-click on the new **Server Audit** and select **Enable Server Audit**.
#### T-SQL Method
Execute code similar to:
```
CREATE SERVER AUDIT TrackLogins
TO APPLICATION_LOG;
GO
CREATE SERVER AUDIT SPECIFICATION TrackAllLogins
FOR SERVER AUDIT TrackLogins
 ADD (FAILED_LOGIN_GROUP),
 ADD (SUCCESSFUL_LOGIN_GROUP),
 ADD (AUDIT_CHANGE_GROUP)
WITH (STATE = ON);
GO
ALTER SERVER AUDIT TrackLogins
WITH (STATE = ON);
GO
```
**Note:** If the write destination for the Audit object is to be the security event log, see the Books Online topic [Write SQL Server Audit Events to the Security Log](https://docs.microsoft.com/en-us/sql/relational-databases/security/auditing/write-sql-server-audit-events-to-the-security-log) and follow the appropriate steps.

*/


/*Ensure Database and Application User Input is Sanitized

Always validate user input received from a database client or application by testing type, length, format, and range prior to transmitting it to the database server.

Sanitizing user input drastically minimizes risk of SQL injection.

Check with the application teams to ensure any database interaction is through the use of stored procedures and not dynamic SQL. Revoke any `INSERT`, `UPDATE`, or `DELETE` privileges to users so that modifications to data must be done through stored procedures. Verify that there's no SQL query in the application code produced by string concatenation.

The following steps can be taken to remediate SQL injection vulnerabilities:
- Review TSQL and application code for SQL Injection
- Only permit minimally privileged accounts to send user input to the server
- Minimize the risk of SQL injection attack by using parameterized commands and stored procedures
- Reject user input containing binary data, escape sequences, and comment characters
- Always validate user input and do not use it directly to build SQL statements

*/



/*Ensure 'CLR Assembly Permission Set' is set to 'SAFE_ACCESS' for All CLR Assemblies

Setting CLR Assembly Permission Sets to `SAFE_ACCESS` will prevent assemblies from accessing external system resources such as files, the network, environment variables, or the registry.

Assemblies with `EXTERNAL_ACCESS` or `UNSAFE` permission sets can be used to access sensitive areas of the operating system, steal and/or transmit data and alter the state and other protection measures of the underlying Windows Operating System.

Assemblies which are Microsoft-created (`is_user_defined = 0`) are excluded from this check as they are required for overall system functionality.

Execute the following SQL statement:
*/
USE SolarWindsOrion;
GO
SELECT name,
 permission_set_desc
FROM sys.assemblies
WHERE is_user_defined = 1;

/*All the returned assemblies should show `SAFE_ACCESS` in the `permission_set_desc` column.*/
/*
```
USE <database_name>;
GO
ALTER ASSEMBLY <assembly_name> WITH PERMISSION_SET = SAFE;

*/


/*Ensure 'Symmetric Key encryption algorithm' is set to 'AES_128' or higher in non-system databases

Per the Microsoft Best Practices, only the SQL Server AES algorithm options, `AES_128`, `AES_192`, and `AES_256`, should be used for a symmetric key encryption algorithm.

The following algorithms (as referred to by SQL Server) are considered weak or deprecated and should no longer be used in SQL Server: `DES`, `DESX`, `RC2`, `RC4`, `RC4_128`.

Many organizations may accept the Triple DES algorithms (`TDEA`) which use keying options 1 (3 key aka `3TDEA`) or keying option 2 (2 key aka `2TDEA`). In SQL Server, these are referred to as `TRIPLE_DES_3KEY` and `TRIPLE_DES` respectively. Additionally, the SQL Server algorithm named DESX is actually the same implementation as the `TRIPLE_DES_3KEY` option. However, using the DESX identifier as the algorithm type has been deprecated and its usage is now discouraged.

Run the following code for each individual user database:
```
*/


USE SolarWindsOrion
GO
SELECT db_name() AS Database_Name, name AS Key_Name
FROM sys.symmetric_keys
WHERE algorithm_desc NOT IN ('AES_128','AES_192','AES_256')
AND db_id() > 4;
GO

/*For compliance, no rows should be returned.*/

/*Refer to Microsoft SQL Server Books Online ALTER SYMMETRIC KEY entry: [https://docs.microsoft.com/en-us/sql/t-sql/statements/alter-symmetric-key-transact-sql](https://docs.microsoft.com/en-us/sql/t-sql/statements/alter-symmetric-key-transact-sql) */



/*Ensure Asymmetric Key Size is set to 'greater than or equal to 2048' in non-system databases
Microsoft Best Practices recommend to use at least a 2048-bit encryption algorithm for asymmetric keys.

The `RSA_2048` encryption algorithm for asymmetric keys in SQL Server is the highest bit-level provided and therefore the most secure available choice (other choices are `RSA_512` and `RSA_1024`).

Run the following code for each individual user database:
*/

USE SolarWindsOrion
GO
SELECT db_name() AS Database_Name, name AS Key_Name
FROM sys.asymmetric_keys
WHERE key_length < 2048
AND db_id() > 4;
GO

/*For compliance, no rows should be returned.*/

/*Refer to Microsoft SQL Server Books Online ALTER ASYMMETRIC KEY entry: [https://docs.microsoft.com/en-us/sql/t-sql/statements/alter-asymmetric-key-transact-sql](https://docs.microsoft.com/en-us/sql/t-sql/statements/alter-asymmetric-key-transact-sql) */


/*Ensure 'SQL Server Browser Service' is configured correctly
No recommendation is being given on disabling the SQL Server Browser service.
In the case of a default instance installation, the SQL Server Browser service is disabled by default. Unless there is a named instance on the same server, there is typically no reason for the SQL Server Browser service to be running. In this case it is strongly suggested that the SQL Server Browser service remain disabled.


Check the SQL Browser service's status via `services.msc` or similar methods.

Enable or disable the service as needed for your environment.

*/





