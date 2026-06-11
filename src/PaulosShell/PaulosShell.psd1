@{
  RootModule = 'PaulosShell.psm1'
  ModuleVersion = '0.2.4'
  GUID = 'd35520f2-2b69-4565-b500-e1706ee085cd'
  Author = 'Diogo Paulos'
  CompanyName = 'Paulos Shell'
  Copyright = '(c) Diogo Paulos. All rights reserved.'
  Description = 'A safe, updateable PowerShell dev-shell toolkit with a paulos command center.'
  PowerShellVersion = '7.0'
  FunctionsToExport = @(
    # Core
    'Initialize-PaulosShell',
    'paulos',
    'Install-PaulosDevShellTools',
    'Install-DevShellTools',
    'shellcheck',

    # Paulos command center internals/actions
    'Invoke-PaulosSetup',
    'Invoke-PaulosDoctor',
    'Invoke-PaulosWizard',
    'Invoke-PaulosDelta',
    'Invoke-PaulosFont',
    'Invoke-PaulosStarship',
    'Invoke-PaulosGithub',
    'Invoke-PaulosUpdate',
    'Invoke-PaulosPnpm',
    'Show-PaulosHelp',
    'Show-PaulosCommands',
    'Show-PaulosTools',
    'Show-PaulosModules',
    'Show-PaulosFull',
    'Show-PaulosTip',
    'Show-PaulosVersion',
    'Get-PaulosCurrentVersion',
    'Backup-PaulosProfile',
    'Restore-PaulosProfile',

    # Biome
    'lint',
    'format',
    'check',

    # pnpm/package helpers
    'sex',
    'su',
    'run',
    'dev',
    'debug',
    'build',
    'test',
    'e2e',
    'i',
    'add',
    'un',
    'up',
    'remove',
    'dlx',
    'why',
    'outdated',
    'approve',

    # UI/DX tools
    'ishadcn',
    'shadcn',
    'magicui',

    # File helpers
    'll',
    'ls',
    'lt',
    'npp',
    'icogen',
    'grep',
    'todo',
    'ff',

    # Git/GitHub
    'gst',
    'gss',
    'gadd',
    'gcommit',
    'gpush',
    'gpull',
    'glog',
    'gdiff',
    'gbranch',
    'gcheckout',
    'lg',
    'prs',
    'prc',
    'prv',

    # .NET
    'dn',
    'dnb',
    'dnr',
    'dnt',
    'dnw',
    'dnc',
    'ef',
    'efadd',
    'efup',

    # Project/system helpers
    'codehere',
    'reload',
    'profile',
    'whereis',
    'scripts',
    'ports',
    'port',
    'killport',
    'mkcd',
    'touch',
    'open'
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



