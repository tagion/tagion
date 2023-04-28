INSTALLDIR?=$(HOME)/.local/share/dart_api/
DC?=dmd

install:
	# dub build --compiler=$(DC)
	mkdir -p $(INSTALLDIR) 
	mkdir -p $(HOME)/.config/systemd/user
	cp vibed-project $(INSTALLDIR)/
	cp dart_api.service $(HOME)/.config/systemd/user/
	systemctl daemon-reload
	systemctl restart --user dart_api
