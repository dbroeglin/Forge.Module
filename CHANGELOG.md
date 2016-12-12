## 0.4.1 (2016-12-12)

 * Export only New-ForgeModule and New-ForgeModuleFunction

## 0.4.0 (2016-12-12)

 * Added import for Forge
 * Aligning more closely to what Plaster generates
 * Corrected issue with 'FunctionsToExport' update when adding first function
 * Added directory layout alternative -Layout (either 'src' or 'ModuleName')

## 0.3.0 (2016-11-29)

 * Added an about_Forge.Module topic
 * Added module loadin test
 * Added skeleton about_Module_help.txt file (from Plaster)

## 0.2.1 (2016-11-15)

 * Solved portability issue when excluding templates dir
 * Renaming PSake parameter names to InvokeBuild ones
 * Added documentation for InvokeBuild
 * First shot a integration InvokeBuild (copied from nightroman/Plaster)

## 0.2.0 (2016-11-12)

 * Changed default tests root dir
 * Added more tests for build files
 * Changed PSD1 encoding to UTF-8
 * Added support for PSake (copied from Plaster)
 * Added AppVeyor Pester execution
 * Added support for VSCode (copied from Plaster)
 * Added optional .gitignore generation
 
## 0.1.0 (2016-10-16)

 * Cleanup and better documentation
 * Properly generate parameter names
 * Renamed all templates to .eps
 * Refactored to use the shared context added in Forge
 * Refactored New-ForgeModule and New-ForgeModuleFunction out of the 'Forge' module