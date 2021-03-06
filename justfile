# https://github.com/casey/just

##################################################
# constants
version = `sed -En 's/version = "([^"]+)"/\1/p' Cargo.toml`
target = "$PWD/target"
nightly = "CARGO_TARGET_DIR=$TG/nightly CARGO_INCREMENTAL=1 rustup run nightly"

##################################################
# build commands
build: # build app with web=false
	cargo build
	echo "built binary to: target/stable/debug/art"

build-dev: # build using nightly and incremental compilation
	TG={{target}} {{nightly}} cargo build
	echo "built binary to: target/nightly/debug/art"

build-elm: # build just elm (not rust)
	(cd web-ui; npm run build)
	(cd web-ui/dist; tar -cvf ../../src/api/data/web-ui.tar *)

build-static: # build and package elm as a static index.html
	(cd web-ui; elm make src/Main-Static.elm)
	rm -rf target/web
	mkdir target/web
	cp web-ui/index.html target/web
	cp -r web-ui/css target/web
	# copy and link the style sheets
	sed -e 's/<head>/<head><link rel="stylesheet" type="text\/css" href="css\/index.css" \/>/g' target/web/index.html -i
	(cd target/web; tar -cvf ../../src/cmd/data/web-ui-static.tar *)

build-web: build-elm build-static
	cargo build

##################################################
# unit testing/linting commands
test: # do tests with web=false
	RUST_BACKTRACE=1 cargo test --lib

test-dev: # test using nightly and incremental compilation
	TG={{target}} {{nightly}} cargo test --lib

test-elm: 
	(cd web-ui; elm test)

test-all: test-elm test

filter PATTERN: # run only specific tests
	RUST_BACKTRACE=1 cargo test --lib {{PATTERN}}

lint: # run linter
	CARGO_TARGET_DIR={{target}}/nightly rustup run nightly cargo clippy
	
test-server: build-elm # run the test-server for e2e testing, still in development
	(cargo run -- --work-tree web-ui/e2e_tests/ex_proj -v server)

test-e2e: # run e2e tests, still in development
	(cd web-ui; py2t e2e_tests/basic.py)

##################################################
# running commands

api: # run the api server (without the web-ui)
	cargo run -- -v server

serve: build-elm  # run the full frontend
	cargo run -- -v server

self-check: # build self and run `art check` using own binary
	cargo run -- check

##################################################
# release command

fmt:
	cargo fmt -- --write-mode overwrite  # don't generate *.bk files
	art fmt -w

check-fmt:
	cargo fmt -- --write-mode=diff

check-art:
	art check

check: check-art check-fmt

git-verify: # make sure git is clean and on master
	git branch | grep '* master'
	git diff --no-ext-diff --quiet --exit-code

publish: git-verify lint build-web test-all check # publish to github and crates.io
	git commit -a -m "v{{version}} release"
	just publish-cargo
	just publish-git

export-site: build-web
	rm -rf _gh-pages/index.html _gh-pages/css
	art export html && mv index.html css _gh-pages

publish-site: export-site
	rm -rf _gh-pages/index.html _gh-pages/css
	art export html && mv index.html css _gh-pages
	(cd _gh-pages; git commit -am 'v{{version}}' && git push origin gh-pages)

publish-cargo: # publish cargo without verification
	cargo publish --no-verify

publish-git: # publish git without verification
	git push origin master
	git tag -a "v{{version}}" -m "v{{version}}"
	git push origin --tags


##################################################
# developer installation helpers

update: # update rust and tools used by this lib
	rustup update
	(cargo install just -f)
	(cargo install rustfmt -f)
	rustup run nightly cargo install clippy -f

install-nightly:
	rustup install nightly
