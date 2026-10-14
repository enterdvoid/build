# @description 9Router AI firmware variant. The common helper is sourced only when this variant is enabled.
DBAI_AI_STACK_MODE=9router
source "$(dirname "${BASH_SOURCE[0]}")/ai-stack-common.sh"

function extension_prepare_config__dbai_ai_router9() {
	dbai_ai_stack_prepare_config "9Router" "-9router"
}

function post_repo_customize_image__dbai_prepare_ai_stack() {
	dbai_ai_stack_prepare_image
}
