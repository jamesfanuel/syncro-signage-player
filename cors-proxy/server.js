const cors_proxy = require('cors-anywhere');

cors_proxy.createServer({
    originWhitelist: [], // mengizinkan semua origin
    requireHeader: [],
    removeHeaders: []
}).listen(8080, () => {
    console.log('✅ CORS Proxy berjalan di http://localhost:8080');
});
