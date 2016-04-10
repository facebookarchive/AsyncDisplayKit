# ComponentKit Documentation 

We use [Jekyll](http://jekyllrb.com/) to build the site using Markdown and host it on [Github Pages](https://pages.github.com/).

## Installation

To contribute to the site or add to the documentation, you will have to set up a local copy of the site on your development machine.

### Dependencies

Github Pages uses Jekyll to host a site and Jekyll has the following dependencies.

 - [Ruby](http://www.ruby-lang.org/) (version >= 1.8.7)
 - [RubyGems](http://rubygems.org/) (version >= 1.3.7)
 - [Bundler](http://gembundler.com/)

Mac OS X comes pre-installed with Ruby, but you may need to update RubyGems (via `gem update --system`).
Otherwise, [RVM](https://rvm.io/) and [rbenv](https://github.com/sstephenson/rbenv) are popular ways to install Ruby.
Once you have RubyGems and installed Bundler (via `gem install bundler`), use it to install the dependencies:

```sh
$ cd componentkit # Go to folder
$ bundle install # Might need sudo.
```

### Instructions

Use Jekyll to serve the website locally (by default, at `http://localhost:4000`):

```sh
$ cd componentkit # Go to folder
$ git checkout docs
$ bundle exec jekyll serve -w
$ open http://localhost:4000/
```
