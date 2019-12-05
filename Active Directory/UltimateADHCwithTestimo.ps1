Install-Module Testimo -Force -Verbose

$Sources = @(

    'ForestRoles'

    'ForestOptionalFeatures'

    'ForestOrphanedAdmins'

    'DomainPasswordComplexity'

    'DomainKerberosAccountAge'

    'DomainDNSScavengingForPrimaryDNSServer'

    'DomainSysVolDFSR'

    'DCRDPSecurity'

    'DCSMBShares'

    'DomainGroupPolicyMissingPermissions'

    'DCWindowsRolesAndFeatures'

    'DCNTDSParameters'

    'DCInformation'

    'ForestReplicationStatus'

)



Invoke-Testimo -Sources $Sources -ShowReport