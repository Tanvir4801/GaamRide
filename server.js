const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 5000;

const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>GaamRide - Village Transport App</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #f0f4f8;
      color: #1a202c;
      min-height: 100vh;
    }
    header {
      background: linear-gradient(135deg, #2d6a4f 0%, #40916c 100%);
      color: white;
      padding: 2rem;
      text-align: center;
      box-shadow: 0 2px 8px rgba(0,0,0,0.2);
    }
    header h1 { font-size: 2.5rem; font-weight: 700; letter-spacing: -1px; }
    header p { margin-top: 0.5rem; font-size: 1.1rem; opacity: 0.85; }
    .badge {
      display: inline-block;
      background: rgba(255,255,255,0.2);
      border-radius: 20px;
      padding: 4px 14px;
      font-size: 0.85rem;
      margin-top: 0.75rem;
    }
    main { max-width: 900px; margin: 2rem auto; padding: 0 1rem; }
    .card {
      background: white;
      border-radius: 12px;
      padding: 1.5rem;
      margin-bottom: 1.5rem;
      box-shadow: 0 1px 4px rgba(0,0,0,0.08);
    }
    .card h2 {
      font-size: 1.2rem;
      font-weight: 600;
      color: #2d6a4f;
      margin-bottom: 1rem;
      padding-bottom: 0.5rem;
      border-bottom: 2px solid #d8f3dc;
    }
    .tech-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
      gap: 0.75rem;
    }
    .tech-item {
      background: #f7fdf9;
      border: 1px solid #d8f3dc;
      border-radius: 8px;
      padding: 0.75rem 1rem;
      text-align: center;
      font-size: 0.9rem;
    }
    .tech-item strong { display: block; color: #1b4332; font-size: 0.75rem; margin-bottom: 2px; text-transform: uppercase; letter-spacing: 0.5px; }
    .roles-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
      gap: 1rem;
    }
    .role-card {
      border-radius: 8px;
      padding: 1rem;
    }
    .role-card.customer { background: #ebf8ff; border-left: 4px solid #3182ce; }
    .role-card.saathi { background: #f0fff4; border-left: 4px solid #38a169; }
    .role-card.owner { background: #fffaf0; border-left: 4px solid #dd6b20; }
    .role-card h3 { font-size: 1rem; font-weight: 600; margin-bottom: 0.5rem; }
    .role-card ul { list-style: none; font-size: 0.875rem; color: #4a5568; }
    .role-card ul li::before { content: "→ "; color: #718096; }
    .structure-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
      gap: 0.75rem;
    }
    .dir-item {
      background: #f8f9fa;
      border-radius: 8px;
      padding: 0.75rem;
      font-size: 0.875rem;
    }
    .dir-item code {
      display: block;
      font-family: monospace;
      font-size: 0.85rem;
      color: #2d6a4f;
      font-weight: 600;
      margin-bottom: 4px;
    }
    .info-box {
      background: #fff3cd;
      border: 1px solid #ffc107;
      border-radius: 8px;
      padding: 1rem 1.25rem;
      font-size: 0.9rem;
      color: #856404;
    }
    .info-box strong { display: block; margin-bottom: 4px; }
    .screens-list {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
      gap: 0.5rem;
    }
    .screen-item {
      background: #f8f9fa;
      border-radius: 6px;
      padding: 0.5rem 0.75rem;
      font-family: monospace;
      font-size: 0.82rem;
      color: #2d3748;
    }
  </style>
</head>
<body>
  <header>
    <h1>🚗 GaamRide</h1>
    <p>Village-based Transport Application</p>
    <span class="badge">Flutter + Firebase Mobile App</span>
  </header>
  <main>
    <div class="info-box">
      <strong>Note: This is a Flutter mobile application</strong>
      Flutter apps are built for Android/iOS devices. This page is a project overview. To run the app, use <code>flutter run</code> with a connected device or emulator.
    </div>

    <div class="card" style="margin-top:1.5rem">
      <h2>About GaamRide</h2>
      <p style="color:#4a5568;line-height:1.6">GaamRide connects local transport providers (<strong>Gaam Saathi</strong>) with customers in rural/village areas. It supports multiple user roles with features for booking rides, real-time tracking, proximity-based driver discovery, and push notifications.</p>
    </div>

    <div class="card">
      <h2>Tech Stack</h2>
      <div class="tech-grid">
        <div class="tech-item"><strong>Frontend</strong>Flutter (Dart)</div>
        <div class="tech-item"><strong>Backend</strong>Firebase</div>
        <div class="tech-item"><strong>Database</strong>Cloud Firestore</div>
        <div class="tech-item"><strong>Auth</strong>Firebase Auth</div>
        <div class="tech-item"><strong>Functions</strong>Node.js 18</div>
        <div class="tech-item"><strong>Maps</strong>Google Maps SDK</div>
        <div class="tech-item"><strong>Notifications</strong>FCM</div>
        <div class="tech-item"><strong>Location</strong>Geolocator</div>
      </div>
    </div>

    <div class="card">
      <h2>User Roles</h2>
      <div class="roles-grid">
        <div class="role-card customer">
          <h3>👤 Customer</h3>
          <ul>
            <li>Search for nearby Saathis</li>
            <li>Book transport rides</li>
            <li>Track ride in real-time</li>
            <li>View booking history</li>
          </ul>
        </div>
        <div class="role-card saathi">
          <h3>🚘 Gaam Saathi (Driver)</h3>
          <ul>
            <li>Register as transport provider</li>
            <li>Accept/reject ride requests</li>
            <li>Manage availability status</li>
            <li>View earnings & history</li>
          </ul>
        </div>
        <div class="role-card owner">
          <h3>🏢 Vehicle Owner</h3>
          <ul>
            <li>Register vehicles</li>
            <li>Manage fleet</li>
            <li>Track vehicle usage</li>
            <li>GaamHaul (goods transport)</li>
          </ul>
        </div>
      </div>
    </div>

    <div class="card">
      <h2>App Screens</h2>
      <div class="screens-list">
        <div class="screen-item">auth_gate_screen.dart</div>
        <div class="screen-item">otp_verification_screen.dart</div>
        <div class="screen-item">role_selection_screen.dart</div>
        <div class="screen-item">home_screen.dart</div>
        <div class="screen-item">customer_home_screen.dart</div>
        <div class="screen-item">booking_search_screen.dart</div>
        <div class="screen-item">booking_request_screen.dart</div>
        <div class="screen-item">tracking_screen.dart</div>
        <div class="screen-item">saathi_dashboard.dart</div>
        <div class="screen-item">saathi_register_screen.dart</div>
        <div class="screen-item">vehicle_owner_dashboard.dart</div>
        <div class="screen-item">vehicle_register_screen.dart</div>
        <div class="screen-item">gaam_haul_home_screen.dart</div>
        <div class="screen-item">main_shell.dart</div>
      </div>
    </div>

    <div class="card">
      <h2>Project Structure</h2>
      <div class="structure-grid">
        <div class="dir-item"><code>lib/screens/</code>UI screens for all app flows</div>
        <div class="dir-item"><code>lib/services/</code>Auth, booking, location, notifications</div>
        <div class="dir-item"><code>lib/models/</code>Data models (booking, saathi, village)</div>
        <div class="dir-item"><code>lib/widgets/</code>Reusable UI components</div>
        <div class="dir-item"><code>lib/utils/</code>App constants and themes</div>
        <div class="dir-item"><code>functions/</code>Firebase Cloud Functions (Node.js)</div>
        <div class="dir-item"><code>android/</code>Android native configuration</div>
        <div class="dir-item"><code>ios/</code>iOS native configuration</div>
        <div class="dir-item"><code>assets/</code>Images and static assets</div>
        <div class="dir-item"><code>web/</code>Flutter web template</div>
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
