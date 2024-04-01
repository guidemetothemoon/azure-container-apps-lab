// Re-used from https://github.com/Azure/bicep/issues/5703#issuecomment-2004230485

@description('User-defined, re-usable function that can be used to replace multiple strings in a specific string, which is currently not supported out of the box by the replace() function in Bicep.')
@export()
func replaceMultipleStrings(input string, replacements { *: string }) string => reduce(
  items(replacements), input, (cur, next) => replace(string(cur), next.key, next.value))
