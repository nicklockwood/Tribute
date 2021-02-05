[![Travis](https://api.travis-ci.org/nicklockwood/Tribute.svg?branch=master)](https://travis-ci.org/nicklockwood/Tribute)
[![Swift 5.1](https://img.shields.io/badge/swift-5.1-red.svg?style=flat)](https://developer.apple.com/swift)
[![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://opensource.org/licenses/MIT)
[![Twitter](https://img.shields.io/badge/twitter-@nicklockwood-blue.svg)](http://twitter.com/nicklockwood)

Tribute
========

Many open source libraries or frameworks using popular licenses such as MIT or BSD require attribution as part of their licensing conditions. This means that apps using those frameworks need to include the license somewhere (typically in the settings screen).

Remembering to include all of those licenses and keeping them up-to-date is a frustratingly manual process. It's easy to forget, which can potentially have serious ramifications if the library vendor is litigious.

Tribute is a command-line tool to simplify the process of generating, checking and maintaining open source licenses in your projects.


Installation
------------

You can install the tool on macOS either by building it yourself from source, or by using [Mint](https://github.com/yonaskolb/Mint) as follows:

```bash
$ mint install nicklockwood/Tribute
```


Usage
------

Once you have installed the `tribute` command-line tool you can run it as follows:

```bash
$ cd path/to/your/project
$ tribute list
```

If run from inside your project, this command should list all the open source libraries that you are using. You may find that some libraries are included that you don't think should be. You can ignore these either by using `--skip library-name` and/or `--exclude subfolder` as follows:

```bash
$ tribute list --exclude Tests --skip UnusedKit
```

If any libraries are missing, make sure they have a valid `LICENSE` file. Only libraries that include a standard open source license file will be detected by the Tribute tool.


Advanced
---------

In addition to listing the licenses in a project, Tribute can also generate a file for display in your app or web site. To generate a licenses file, use the following command (note that the file name:

```bash
$ tribute export path/to/acknowledgements-file.json
```

Tribute offers a variety of options for configuring the format and structure of this file. For more details run the following command:

```bash
$ tribute help export
```

Once you have generated a licenses file and integreated it into your app or website, you might want to configure a script to update it every time you build. To set this up in Xcode, do the following:

1. Click on your project in the file list, choose your target under `TARGETS`, click the `Build Phases` tab
2. Add a `New Run Script Phase` by clicking the little plus icon in the top left and paste in the following script:

```bash
if which tribute >/dev/null; then
  tribute export path/to/acknowledgements-file.json
else
  echo "warning: Tribute not installed, download from https://github.com/nicklockwood/Tribute"
fi
```

If you have a CI (Continuous Integration) setup, you probably don't want to generate this file on the server, but you might want to validate that it has been run as part of your automated test suite. To do that, you can use the `check` command as follows:

```bash
$ tribute check path/to/acknowledgements-file.json
```

This command won't change any files, but will produce an error if any non-excluded libraries are missing from the licenses file.


Known issues
-------------

* Dependency scanning is quite slow for large projects, especially for projects that include Swift Package Manager dependencies. This will be improved in future.

* Dependency scanning only works if the dependencies have been checked out. If you are using git submodules, or a package manager such as CocoaPods, Carthage or Swift Package Manager, make sure your dependencies have all been resolved before running Tribute (if you are able to successfuly build your app you can assume that the dependencies have been resolved).

* Tribute can only detect dependencies that include a LICENSE file (with or without file extensions). If you have copied a dependency without the LICENSE file, or if the dependency doesn't include such a file, it won't be detected. If you encounter such cases please open an issue and I'll try to find a solution.
