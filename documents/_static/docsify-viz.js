let viz = new Viz();


(function() {
	var viz_plugin = function(hook, vm) {
		console.log("loaded viz.js");

		hook.doneEach(function() {
			window.Docsify.dom.findAll('pre[data-lang="graphviz"]').forEach(async element => {
				viz.renderSVGElement(element.innerText).then(svg => {
					element.replaceWith(svg)
				}
				);
			})
		})
	};

	// Add plugin to docsify's plugin array
	$docsify = $docsify || {};
	$docsify.plugins = [].concat($docsify.plugins || [], viz_plugin);
})();
