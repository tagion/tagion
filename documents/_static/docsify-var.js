
(function() {
	var var_plugin = function(hook, vm) {
		const config = vm.config;

		function replaceSchemas(origin, descendant) {
			let ddocs = Docsify.dom.findAll("a")
			.filter(a => {let h = a.href; 
				return h.startsWith(origin)
			})

			ddocs.forEach(
				a => {
					let h = a.href; 
					a.href = h.replace(origin, descendant)
			})
		}

		hook.doneEach(function() {
			config.schemas.forEach(
				scheme => replaceSchemas(scheme[0], scheme[1])
			);
		})

	};

	// Add plugin to docsify's plugin array
	$docsify = $docsify || {};
	$docsify.plugins = [].concat($docsify.plugins || [], var_plugin);
})();
