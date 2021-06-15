/*SQL Server patches contain program updates that fix security and product functionality issues found in the software. 
These patches can be installed with a security update, which is a single patch, or a cumulative update which is a group of patches. 
The SQL Server version and patch levels should be the most recent compatible with the organizations' operational needs.
*/

/* Dave Kawula -06/01/2021 Check the value and if not at the current patch level get a plan to get updated
This could require and outage of production SQL so properly change control should be followed
*/

SELECT SERVERPROPERTY('ProductLevel') as SP_installed, SERVERPROPERTY('ProductVersion') as Version;



/* Surface Area Reduction - SQL Server offers various configuration options, some of them can be controlled by the `sp_configure` stored procedure. 
This section contains the listing of the corresponding recommendations.
*/

EXECUTE sp_configure 'show advanced options', 1;


/*Both value columns must show `0`.*/
SELECT name, CAST(value as int) as value_configured, CAST(value_in_use as int) as value_in_use 
FROM sys.configurations 
WHERE name = 'Ad Hoc Distributed Queries';

/*If value not 0 remediate with*/

EXECUTE sp_configure 'show advanced options', 1;
RECONFIGURE;
EXECUTE sp_configure 'Ad Hoc Distributed Queries', 0;
RECONFIGURE;
GO
EXECUTE sp_configure 'show advanced options', 0;
RECONFIGURE; 

/*Enabling use of CLR assemblies widens the attack surface of SQL Server and puts it at risk from both inadvertent and malicious assemblies.*/

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

/*To fix this run*/

EXECUTE sp_configure 'clr enabled', 0;
RECONFIGURE;


/*The `cross db ownership chaining` option controls cross-database ownership chaining across all databases at the instance (or server) level.
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

/*To Remediate*/
EXECUTE sp_configure 'cross db ownership chaining', 0;
RECONFIGURE;
GO 



/*The `Database Mail XPs` option controls the ability to generate and transmit email messages from SQL Server.
Disabling the `Database Mail XPs` option reduces the SQL Server surface, eliminates a DOS attack vector and channel to exfiltrate data from the database server to a remote host.
*/

SELECT name,
 CAST(value as int) as value_configured,
 CAST(value_in_use as int) as value_in_use
FROM sys.configurations
WHERE name = 'Database Mail XPs';

/*Both value columns must show `0` to be compliant.*/

/*Remediation*/

EXECUTE sp_configure 'show advanced options', 1;
RECONFIGURE;
EXECUTE sp_configure 'Database Mail XPs', 0;
RECONFIGURE;
GO
EXECUTE sp_configure 'show advanced options', 0;
RECONFIGURE;



/* The `Ole Automation Procedures` option controls whether OLE Automation objects can be instantiated within Transact-SQL batches. 
These are extended stored procedures that allow SQL Server users to execute functions external to SQL Server.

Enabling this option will increase the attack surface of SQL Server and allow users to execute functions in the security context of SQL Server.

*/

SELECT name, 
 CAST(value as int) as value_configured, 
 CAST(value_in_use as int) as value_in_use 
FROM sys.configurations 
WHERE name = 'Ole Automation Procedures'; 



/*Both value columns must show `0` to be compliant.*/

/*Remediation*/

EXECUTE sp_configure 'show advanced options', 1;
RECONFIGURE;
EXECUTE sp_configure 'Ole Automation Procedures', 0;
RECONFIGURE;
GO
EXECUTE sp_configure 'show advanced options', 0;
RECONFIGURE;


/*The `remote access` option controls the execution of local stored procedures on remote servers or remote stored procedures on local server.
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

/*Remediation */


EXECUTE sp_configure 'remote admin connections', 0;
RECONFIGURE;
GO


/*The `scan for startup procs` option, if enabled, causes SQL Server to scan for and automatically run all stored procedures that are set to execute upon service startup.
Enforcing this control reduces the threat of an entity leveraging these facilities for malicious purposes.
*/

SELECT name,
 CAST(value as int) as value_configured,
 CAST(value_in_use as int) as value_in_use
FROM sys.configurations
WHERE name = 'scan for startup procs';

/*Both value columns must show `0`.*/

/*Remediation*/

EXECUTE sp_configure 'show advanced options', 1;
RECONFIGURE;
EXECUTE sp_configure 'scan for startup procs', 0;
RECONFIGURE;
GO
EXECUTE sp_configure 'show advanced options', 0;
RECONFIGURE;

/*Restart the Database Engine.*/


/*The `TRUSTWORTHY` database option allows database objects to access objects in other databases under certain circumstances.
Provides protection from malicious CLR assemblies or extended procedures.
*/

/*Run the following T-SQL query to list any databases with a Trustworthy database property value of `ON`:*/

SELECT name
FROM sys.databases
WHERE is_trustworthy_on = 1
AND name != 'msdb';

/*No rows should be returned.*/

/*Remediation*/

/*Execute the following T-SQL statement against the databases (replace _`<database_name>`_ below) returned by the Audit Procedure:*/

ALTER DATABASE [<database_name>] SET TRUSTWORTHY OFF;



/*SQL Server supports Shared Memory, Named Pipes, and TCP/IP protocols. However, SQL Server should be configured to use the bare minimum required based on the organization's needs.
Using fewer protocols minimizes the attack surface of SQL Server and, in some cases, can protect it from remote attacks.
Open **SQL Server Configuration Manager**; go to the **SQL Server Network Configuration**. Ensure that only required protocols are enabled.
Open **SQL Server Configuration Manager**; go to the **SQL Server Network Configuration**. Ensure that only required protocols are enabled. Disable protocols not necessary.
*/



/*If installed, a default SQL Server instance will be assigned a default port of `TCP:1433` for TCP/IP communication. 
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


