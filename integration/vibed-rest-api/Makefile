INSTALLDIR?=$(HOME)/.local/share/dart_api/
export DC?=dmd

install:
	dub build --compiler=$(DC)
	systemctl stop --user dart_api
	mkdir -p $(INSTALLDIR) 
	mkdir -p $(HOME)/.config/systemd/user
	cp vibed-project $(INSTALLDIR)/
	cp dart_api.service $(HOME)/.config/systemd/user/
	systemctl --user daemon-reload
	systemctl start --user dart_api
