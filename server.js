const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 5000;

const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>GaamRide — Village Transport App</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #F5F5F5; color: #212121; }
    header {
      background: linear-gradient(135deg, #1B5E20 0%, #2E7D32 50%, #388E3C 100%);
      color: white; padding: 2.5rem 1.5rem; text-align: center;
    }
    header h1 { font-size: 3rem; font-weight: 900; letter-spacing: -2px; }
    header .tagline { margin-top: 6px; font-size: 1.1rem; opacity: 0.85; }
    .badges { margin-top: 12px; display: flex; gap: 8px; justify-content: center; flex-wrap: wrap; }
    .badge {
      display: inline-block; background: rgba(255,255,255,0.18); border-radius: 20px;
      padding: 4px 14px; font-size: 0.82rem; border: 1px solid rgba(255,255,255,0.3);
    }
    main { max-width: 960px; margin: 2rem auto; padding: 0 1rem 3rem; }
    .card {
      background: white; border-radius: 16px; padding: 1.5rem;
      margin-bottom: 1.5rem; box-shadow: 0 1px 4px rgba(0,0,0,0.07);
      border: 1px solid #E0E0E0;
    }
    .card h2 {
      font-size: 1.15rem; font-weight: 700; color: #2E7D32;
      margin-bottom: 1rem; padding-bottom: 0.5rem;
      border-bottom: 2px solid #E8F5E9;
    }
    .card h2.orange { color: #E65100; border-bottom-color: #FBE9E7; }
    .grid-2 { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 1rem; }
    .grid-3 { display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); gap: 0.75rem; }
    .grid-4 { display: grid; grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); gap: 0.75rem; }
    .tech-item { background: #F9FBE7; border: 1px solid #E8F5E9; border-radius: 10px; padding: 0.75rem 1rem; text-align: center; font-size: 0.88rem; }
    .tech-item strong { display: block; color: #1B5E20; font-size: 0.72rem; margin-bottom: 2px; text-transform: uppercase; letter-spacing: 0.5px; }
    .role-card { border-radius: 12px; padding: 1rem; }
    .role-card.green { background: #E8F5E9; border-left: 4px solid #2E7D32; }
    .role-card.orange { background: #FBE9E7; border-left: 4px solid #E65100; }
    .role-card.blue { background: #E3F2FD; border-left: 4px solid #1565C0; }
    .role-card h3 { font-size: 1rem; font-weight: 700; margin-bottom: 0.5rem; }
    .role-card ul { list-style: none; font-size: 0.875rem; color: #4a5568; }
    .role-card ul li { padding: 2px 0; }
    .role-card ul li::before { content: "→ "; color: #718096; }
    .feature-card { background: #F5F5F5; border-radius: 10px; padding: 1rem; }
    .feature-card .icon { font-size: 1.5rem; margin-bottom: 6px; }
    .feature-card h4 { font-size: 0.92rem; font-weight: 700; margin-bottom: 4px; }
    .feature-card p { font-size: 0.82rem; color: #757575; line-height: 1.4; }
    .screen-item { background: #F5F5F5; border-radius: 8px; padding: 0.5rem 0.75rem; font-family: monospace; font-size: 0.82rem; color: #2d3748; }
    .note { background: #E8F5E9; border: 1px solid #A5D6A7; border-radius: 10px; padding: 1rem 1.25rem; font-size: 0.88rem; color: #1B5E20; }
    .note strong { display: block; margin-bottom: 4px; font-weight: 800; }
    .village-list { display: flex; flex-wrap: wrap; gap: 8px; }
    .village-chip { background: #E8F5E9; border: 1px solid #A5D6A7; border-radius: 20px; padding: 4px 14px; font-size: 0.85rem; color: #1B5E20; font-weight: 600; }
  </style>
</head>
<body>
  <header>
    <div style="font-size:3.5rem; margin-bottom:8px">🛵</div>
    <h1>GaamRide</h1>
    <p class="tagline">ગામડાઓ જોડવા · Connecting Villages · Mahuva Taluka, Surat</p>
    <div class="badges">
      <span class="badge">Flutter Mobile App</span>
      <span class="badge">Firebase Backend</span>
      <span class="badge">Real-time Tracking</span>
      <span class="badge">OTP Verified Rides</span>
      <span class="badge">Parallel Updates</span>
    </div>
  </header>
  <main>
    <div class="note">
      <strong>📱 Flutter Mobile Application</strong>
      This is a Flutter/Dart mobile app built for Android & iOS. This page is the project overview.
      Run with <code>flutter run</code> on a connected device or Android emulator.
    </div>

    <div class="card" style="margin-top:1.5rem">
      <h2>App Overview</h2>
      <p style="line-height:1.7; color:#4a5568; margin-bottom:1rem">
        GaamRide is a village-level transport platform for rural Gujarat, connecting customers with
        <strong>Gaam Saathis</strong> (bike/auto drivers) and <strong>Haul Saathis</strong> (truck/tempo owners)
        in the Mahuva taluka area of Surat district.
      </p>
      <div class="grid-2">
        <div class="role-card green">
          <h3>🟢 GaamRide Module</h3>
          <ul>
            <li>Person transport (like Rapido)</li>
            <li>Real-time Saathi tracking with smooth animation</li>
            <li>OTP verification for ride start</li>
            <li>Star rating after completion</li>
          </ul>
        </div>
        <div class="role-card orange">
          <h3>🟠 GaamHaul Module</h3>
          <ul>
            <li>Vehicle/tempo booking (like Porter)</li>
            <li>Mini Tempo, Pickup, Tractor, 407 Truck</li>
            <li>Duration-based booking (1h to full day)</li>
            <li>Farm & goods transport</li>
          </ul>
        </div>
      </div>
    </div>

    <div class="card">
      <h2>Tech Stack</h2>
      <div class="grid-4">
        <div class="tech-item"><strong>Frontend</strong>Flutter (Dart)</div>
        <div class="tech-item"><strong>Database</strong>Cloud Firestore</div>
        <div class="tech-item"><strong>Auth</strong>Firebase OTP + Google</div>
        <div class="tech-item"><strong>Functions</strong>Node.js 18</div>
        <div class="tech-item"><strong>Maps</strong>Google Maps SDK</div>
        <div class="tech-item"><strong>Notifications</strong>Firebase FCM</div>
        <div class="tech-item"><strong>Geolocation</strong>Geoflutterfire+</div>
        <div class="tech-item"><strong>Storage</strong>Firebase Storage</div>
      </div>
    </div>

    <div class="card">
      <h2>⚡ Core Feature: Parallel Updates</h2>
      <p style="color:#4a5568; margin-bottom:1rem; line-height:1.6">
        The app uses <strong>parallel Firestore writes</strong> via <code>Future.wait()</code> to simultaneously
        update multiple collections when the Saathi's location changes — eliminating serial database bottlenecks.
      </p>
      <div class="grid-3">
        <div class="feature-card">
          <div class="icon">🗂️</div>
          <h4>Ride Doc Update</h4>
          <p>saathiLat, saathiLng, saathiLastUpdate updated in active ride document</p>
        </div>
        <div class="feature-card">
          <div class="icon">📍</div>
          <h4>Saathis Collection</h4>
          <p>GeoFirePoint position updated in saathis collection for discovery</p>
        </div>
        <div class="feature-card">
          <div class="icon">⚡</div>
          <h4>Simultaneously</h4>
          <p>Both writes fire in parallel every 5 seconds — not sequentially</p>
        </div>
      </div>
    </div>

    <div class="card">
      <h2>🎯 Ride Tracking (Core Feature)</h2>
      <div class="grid-3">
        <div class="feature-card">
          <div class="icon">🟢</div>
          <h4>Smooth Marker Animation</h4>
          <p>20-step linear interpolation over 1 second for fluid Saathi marker movement</p>
        </div>
        <div class="feature-card">
          <div class="icon">🔴</div>
          <h4>Real-time Firestore Listener</h4>
          <p>Customer's map updates as Saathi's location changes in Firestore</p>
        </div>
        <div class="feature-card">
          <div class="icon">🔐</div>
          <h4>OTP Verification</h4>
          <p>4-digit OTP ensures Saathi starts ride only after customer confirms identity</p>
        </div>
        <div class="feature-card">
          <div class="icon">📊</div>
          <h4>Status Flow</h4>
          <p>searching → accepted → arriving → started → completed</p>
        </div>
        <div class="feature-card">
          <div class="icon">⭐</div>
          <h4>Ride Rating</h4>
          <p>1-5 star rating submitted by customer at ride completion</p>
        </div>
        <div class="feature-card">
          <div class="icon">💰</div>
          <h4>Fare Calculation</h4>
          <p>₹20 base + ₹8/km, minimum ₹30. Shown before booking.</p>
        </div>
      </div>
    </div>

    <div class="card">
      <h2>User Roles</h2>
      <div class="grid-3">
        <div class="role-card blue">
          <h3>👤 Customer</h3>
          <ul><li>Find nearby Saathi</li><li>Book rides or vehicles</li><li>Track in real-time</li><li>Rate after ride</li></ul>
        </div>
        <div class="role-card green">
          <h3>🛵 Gaam Saathi</h3>
          <ul><li>Online/Offline toggle</li><li>Accept ride requests</li><li>OTP verification</li><li>GPS live updates</li></ul>
        </div>
        <div class="role-card orange">
          <h3>🚛 Haul Saathi</h3>
          <ul><li>Register vehicle</li><li>Accept haul bookings</li><li>Availability toggle</li><li>Earnings tracking</li></ul>
        </div>
      </div>
    </div>

    <div class="card">
      <h2>Service Villages</h2>
      <p style="color:#757575; font-size:0.9rem; margin-bottom:12px">Mahuva Taluka, Surat District, Gujarat — 9 approved villages</p>
      <div class="village-list">
        <span class="village-chip">🏘️ Anaval · આણવલ</span>
        <span class="village-chip">🏘️ Kos · કૉસ</span>
        <span class="village-chip">🏘️ Tarkani · તારકાણી</span>
        <span class="village-chip">🏘️ Angaldhara · અંગળધરા</span>
        <span class="village-chip">🏘️ Dholikuva · ઢોળીકૂવા</span>
        <span class="village-chip">🏘️ Lakhavadi · લખાવડી</span>
        <span class="village-chip">🏘️ Unai · ઉનાઈ</span>
        <span class="village-chip">🏘️ Doldha · ડોળધા</span>
        <span class="village-chip">🏘️ Kamboya · કાંબોયા</span>
      </div>
    </div>

    <div class="card">
      <h2>New Screens Added</h2>
      <div class="grid-4">
        <div class="screen-item">ride_tracking_screen.dart</div>
        <div class="screen-item">ride_complete_screen.dart</div>
        <div class="screen-item">saathi_ride_screen.dart</div>
        <div class="screen-item">haul_tracking_screen.dart</div>
        <div class="screen-item">fare_calculator.dart</div>
        <div class="screen-item">otp_generator.dart</div>
      </div>
    </div>
  </main>
</body>
</html>`;

const server = http.createServer((req, res) => {
  if (req.url === '/favicon.png') {
    const faviconPath = path.join(__dirname, 'web', 'favicon.png');
    if (fs.existsSync(faviconPath)) {
      res.writeHead(200, { 'Content-Type': 'image/png' });
      fs.createReadStream(faviconPath).pipe(res);
      return;
    }
  }
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(html);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log('GaamRide project overview running at http://0.0.0.0:' + PORT);
});
