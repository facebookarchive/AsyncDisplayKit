# AsyncDisplayKit Documentation 

We use [Jekyll](http://jekyllrb.com/) to build the site using Markdown and host it on [Github Pages](https://pages.github.com/).

### Dependencies

Github Pages uses Jekyll to host a site and Jekyll has the following dependencies.

 - [Ruby](http://www.ruby-lang.org/) (version >= 1.8.7)
 - [RubyGems](http://rubygems.org/) (version >= 1.3.7)
 - [Bundler](http://gembundler.com/)

Mac OS X comes pre-installed with Ruby, but you may need to update RubyGems (via `gem update --system`).
Otherwise, [RVM](https://rvm.io/) and [rbenv](https://github.com/sstephenson/rbenv) are popular ways to install Ruby.
Once you have RubyGems and installed Bundler (via `gem install bundler`), use it to install the dependencies.

```sh
$ cd gh-pages # Go to folder
$ bundle install # Might need sudo.
```

### Run Jekyll Locally

Use Jekyll to serve the website locally (by default, at `http://localhost:4000`):

```sh
$ bundle exec jekyll serve
$ open http://localhost:4000/
```
