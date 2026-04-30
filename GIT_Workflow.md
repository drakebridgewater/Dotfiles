## GIT clone, GIT pull and GIT Fetch

GIT clone is the process of creating a working copy of the remote or local repository by passing the following command.

`git clone /path_of_repository`
`git clone username@git_server_hostname:/path_of_repository`
If we have already cloned the repository and need to update local (only code) respect to the remote server, we need to get pull from the remote server by passing following command

`git pull origin master`
When in the above command, git pull is the command, the origin is the remote reference/URL of remote server and master is the branch name.

GIT fetch is the process of updating (only git information) the local GIT structure and information from remote repository. By passing the following command, we can fetch the remote repository.

## GIT Checkout

Git checkout is the event of getting or changing the current state of the git branch to another. When we want to create a branch and move to the created branch, we use the following command.

`git checkout -b <new_branch>`
this will create a branch called <new_branch> and current HEAD will move to the newly created branch. Which means, the changes after this command will be captured in the newly created branch.

## GIT Add and GIT Commit

When we want to add the changes of code to the index of the GIT, we will pass the following command.

`git add <file1> <file2> <file3> git add *`
Basically, this is the first step of the GIT workflow.

GIT commit is the event of adding the index to the HEAD of the local repository. This will be done by passing following command

`git commit -m “your commit message”`
But, this commit will be done only on the local repository. Which mean, we need to push the commits and updated HEAD to the remote repository.

## GIT push

When we commit changes to the local repository, it will have the information about changes in the codebase and its change message with it. So, if we want to update or send the changes to the remote repository, we need to pass the following command.
`git push origin <new_branch>`

When using force make sure to specify the branch when pushing
`git push origin <your_branch_name> --force`

## Branching

* Creating branch in gui: checkout with git checkout MARS-181
* Creating branch in cmd:
  `* git checkout -b NEW_BRANCH_NAME`
  * `git push origin NEW_BRANCH_NAME` (Use when the branch doesn’t exist on remote)

## pull vs fetch

* In the simplest terms, git pull does a git fetch followed by a git merge
* When you use pull, Git tries to automatically do your work for you. It is context sensitive, so Git will merge any pulled commits into the branch you are currently working in. pull automatically merges the commits without letting you review them first. If you don’t closely manage your branches, you may run into frequent conflicts.
* When you fetch, Git gathers any commits from the target branch that do not exist in your current branch and stores them in your local repository. However, it does not merge them with your current branch. This is particularly useful if you need to keep your repository up to date, but are working on something that might break if you update your files. To integrate the commits into your master branch, you use merge.

## What is .git?

* This .git folder is having the following folders and files inside
  * .git/config – File which has main settings and information of the GIT (eg., remote).
  * .git/HEAD – which is having information of which branch you were working on.
  * .git/index – This is a binary file which will act as a checkpoint of the work progress. The Index file will have the information like the list for all files, SHA-1 checksums, timestamps, and name of the files.
  * .git/description – File which will have the description of the repository
  * .git/hooks/ – This is Directory which will have scripts for web-hooking.
  * .git/logs/ – This is Directory of log files which stores all the event of the GIT
  * .git/refs/ – A Directory contains files and its SHA-1 value of references.
All the code changes and other events of the codebase in this directory will be captured in .git folder.

## Resetting work area

* git reset —hard removes all local changes but won’t delete newly added files
* git reset —hard origin/$BRANCH_NAME resets the current git area to exactly what the origin is (origin is gitlab for us)
* git reset HEAD^ back out the latest commit that hasn’t been pushed to origin

## Changing a commit message

* <https://help.github.com/articles/changing-a-commit-message/>

## Squashing (and reset)

* <https://git-scm.com/book/en/v2/Git-Tools-Reset-Demystified>

## Delete a tag everywhere

* git push origin :tagname (Don’t forget the “:” before the tagname)
* Source: <https://stackoverflow.com/questions/5480258/how-to-delete-a-git-remote-tag>

## Patch file from different branch

* git checkout —patch branch2 file.py checkout the file.py from branch2 into the current branch. This will pop up an interactive window for handling this patch the options are displayed below.

```text
y - stage this hunk
n - do not stage this hunk
q - quit; do not stage this hunk nor any of the remaining ones
a - stage this hunk and all later hunks in the file
d - do not stage this hunk nor any of the later hunks in the file
g - select a hunk to go to
/ - search for a hunk matching the given regex
j - leave this hunk undecided, see next undecided hunk
J - leave this hunk undecided, see next hunk
k - leave this hunk undecided, see previous undecided hunk
K - leave this hunk undecided, see previous hunk
s - split the current hunk into smaller hunks
e - manually edit the current hunk
? - print help 
```

## Checked into wrong branch?

* While on the wrong branch get the commit id; it can be found in the log and looks like this: 5464f2bce0af198b1284cdf8cce7bed349cc7ee5
* `git checkout CORRECT_BRANCH`
* `git cherry-pick 5464f2bce0af198b1284cdf8cce7bed349cc7ee5`
* `git commit`
  * This will use the same commit message as the original commit
* Refer to Changing a commit message above for deleting/modifying a commit
