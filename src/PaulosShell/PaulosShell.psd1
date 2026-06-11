@{
    RootModule = 'PaulosShell.psm1'
    ModuleVersion = '0.1.0'
    GUID = 'd35520f2-2b69-4565-b500-e1706ee085cd'
    Author = 'Diogo Paulos'
    CompanyName = 'Paulos Shell'
    Copyright = '(c) Diogo Paulos. All rights reserved.'
    Description = 'A safe, updateable PowerShell dev-shell toolkit with a paulos command center.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Initialize-PaulosShell',
        'paulos',
        'Install-PaulosDevShellTools',
        'Install-DevShellTools',
        'shellcheck',
        'lint','format','check',
        'sex','su','run','dev','debug','build','test','e2e',
        'i','add','un','up','remove','dlx','why','outdated','approve',
        'ishadcn','shadcn','magicui',
        'll','ls','lt','npp','icogen',
        'grep','todo','ff',
        'gst','gss','gadd','gcommit','gpush','gpull','glog','gdiff','gbranch','gcheckout','lg',
        'prs','prc','prv',
        'dn','dnb','dnr','dnt','dnw','dnc','ef','efadd','efup',
        'codehere','reload','profile','whereis','scripts','ports','port','killport','mkcd','touch','open'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('powershell','profile','developer-tools','starship','delta','pnpm')
            ProjectUri = 'https://github.com/dpaulos6/paulos-shell'
            ReleaseNotes = 'Initial safe local installer version.'
        }
    }
}
