# Build paths dynamically
$userProfile = $env:USERPROFILE.Replace('\', '/')
$gpgPath = "$userProfile/scoop/apps/gnupg/current/bin/gpg.exe"
$ghPath = "$userProfile/scoop/shims/gh.exe"

$gitConfig = @"
[alias]
	a = "add"
	c = "commit -v"
	ca = "commit -av"
	co = "checkout"
	d = "diff"
	l = "log --oneline -n 20"
	p = "push"
	pp = "pull"

[commit]
	gpgSign = true

[core]
	editor = "nvim"
	filemode = true
	autocrlf = true
	eol = crlf
	safecrlf = false

[credential "https://gist.github.com"]
	helper = "$ghPath auth git-credential"

[credential "https://github.com"]
	helper = "$ghPath auth git-credential"

[diff]
	noprefix = true

[ghq]
	root = "~/Sources"

[gpg]
	program = "$gpgPath"

[http]
	postBuffer = 157286400
	version = "HTTP/1.1"

[init]
	defaultBranch = "main"

[merge]
	tool = "fugitive"

[mergetool]
	keepBackup = false
	prompt = true
	tool = "fugitive"

[mergetool "fugitive"]
	cmd = "nvim -f -c \"Gvdiffsplit!\" \"$MERGED\""

[pull]
	rebase = false

[push]
	default = "current"

[tag]
	forceSignAnnotated = "true"
	gpgSign = true

[user]
	email = "75213+ivankovnatsky@users.noreply.github.com"
	name = "Ivan Kovnatsky"
	signingKey = "75213+ivankovnatsky@users.noreply.github.com"
"@

$gitConfig | Out-File -FilePath "$HOME\.gitconfig" -Encoding utf8
