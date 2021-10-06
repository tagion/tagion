version-latest:
	@cd $(DIR_TUB); git checkout .
	@cd $(DIR_TUB); git pull origin --force

version-%: 
	@cd $(DIR_TUB); git checkout $(*)
	@cd $(DIR_TUB); git pull origin --force