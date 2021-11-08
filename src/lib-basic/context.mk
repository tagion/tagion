DEPS += lib-logger

${call config.lib, basic}: LOOKUP := tagion/**/*.d
${call config.lib, basic}: LOOKUP += tagion/*.d