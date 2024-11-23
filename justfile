set dotenv-load

run:
    hugo server --buildDrafts

build:
    hugo

deploy-test:
    rm -rf ./public
    hugo --baseURL $SWA_PREVIEW_NAME
    swa deploy -a ./ -d $SWA_TOKEN -O ./public --env preview

deploy-live:
    rm -rf ./public
    hugo --baseURL $SWA_LIVE_NAME
    swa deploy -a ./ -d $SWA_TOKEN -O ./public --env Production
