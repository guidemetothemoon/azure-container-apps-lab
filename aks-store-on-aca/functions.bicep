// Re-used from https://github.com/Azure/bicep/issues/5703#issuecomment-2004230485 
@export()
func replaceMultipleStrings(input string, replacements { *: string }) string => reduce(
  items(replacements), input, (cur, next) => replace(string(cur), next.key, next.value))
