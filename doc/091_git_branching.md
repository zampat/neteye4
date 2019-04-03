# Advanced GIT contribution via branching model

# Introduction

[Get familiar with the branching concepts of git](https://git-scm.com/book/en/v2/Git-Branching-Basic-Branching-and-Merging)

# Operations

Switch to master branch and update local repository
```
git checkout master
git fetch
git pull
git status
```

Define a new branch or switch to an existing one
```
git checkout -b branch_patch_123
```

Now change files and commit those changes into branch:
```
git add changed_file.py
git commit -a -m "important bugfix on python library xyz"
```

Push changes to local repository and remote branch of this name.
[Interesting discussion provided in this thread](https://stackoverflow.com/questions/5082249/pushing-to-git-remote-branch)
```
git push --set-upstream origin branch_patch_123
```


