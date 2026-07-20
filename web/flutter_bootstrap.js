{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    
    // Remove the loading indicator once the app is ready
    const loading = document.querySelector('#loading');
    if (loading) {
      loading.style.opacity = '0';
      loading.style.transition = 'opacity 0.4s ease-out';
      setTimeout(() => {
        loading.remove();
      }, 400);
    }
    
    await appRunner.runApp();
  }
});
