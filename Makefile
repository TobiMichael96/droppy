# os deps: node yarn git jq docker

JQUERY_FLAGS:=-ajax,-css,-deprecated,-effects,-event/alias,-event/focusin,-event/trigger,-wrap,-core/ready,-deferred,-exports/amd,-sizzle,-offset,-dimensions,-serialize,-queue,-callbacks,-event/support,-event/ajax,-attributes/prop,-attributes/val,-attributes/attr,-attributes/support,-manipulation/setGlobalEval,-manipulation/support,-manipulation/var/rcheckableType,-manipulation/var/rscriptType

dev:
	node droppy.js start --dev

test:
	$(MAKE) lint

lint:
	npx eslint --color --ignore-pattern *.min.js server client *.js examples/*.js
	npx stylelint client/*.css

build:
	touch client/client.js
	node droppy.js build

publish:
	if git ls-remote --exit-code origin &>/dev/null; then git push -u -f --tags origin master; fi
	if git ls-remote --exit-code git &>/dev/null; then git push -u -f --tags git master; fi

docker:
	$(eval IMAGE := ausraster/droppy)
	@echo Preparing docker image $(IMAGE)...
	docker pull node:alpine
	sed -i "s/^FROM.\+/FROM node:alpine/g" Dockerfile
	docker rm -f "$$(docker ps -a -f='ancestor=$(IMAGE)' -q)" 2>/dev/null || true
	docker rmi "$$(docker images -qa $(IMAGE))" 2>/dev/null || true
	docker build --no-cache=true --squash -t $(IMAGE) .
	docker tag "$$(docker images -qa $(IMAGE):latest)" $(IMAGE):"$$(cat package.json | jq -r .version)"

	sed -i "s/^FROM.\+/FROM node:alpine/g" Dockerfile

docker-push:
	docker push ausraster/droppy:"$$(cat package.json | jq -r .version)"
	docker push ausraster/droppy:latest

deps:
	rm -rf node_modules
	npm i

update:
	npx updates -u
	$(MAKE) deps
	touch client/client.js

deploy:
	git commit --allow-empty --allow-empty-message -m ""
	if git ls-remote --exit-code demo &>/dev/null; then git push -f demo master; fi
	if git ls-remote --exit-code droppy &>/dev/null; then git push -f droppy master; fi
	git reset --hard HEAD~1

jquery:
	rm -rf /tmp/jquery
	git clone --depth 1 https://github.com/jquery/jquery /tmp/jquery
	cd /tmp/jquery; yarn; grunt; grunt custom:$(JQUERY_FLAGS); grunt remove_map_comment
	cat /tmp/jquery/dist/jquery.min.js | perl -pe 's|"3\..+?"|"3"|' > $(CURDIR)/client/jquery-custom.min.js
	rm -rf /tmp/jquery

ver-patch:
	npx ver patch

ver-minor:
	npx ver minor

ver-major:
	npx ver major

patch: test build ver-patch docker docker-push deploy publish
minor: test build ver-minor docker docker-push deploy publish
major: test build ver-major docker docker-push deploy publish

.PHONY: dev test lint publish docker docker-arm deps update deploy jquery version-patch version-minor version-major patch minor major
