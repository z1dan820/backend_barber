const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const app = express();
const PORT = 3000;

// DATABASE FILES
const DB_FILE = path.join(__dirname, 'slots.json');
const NOTIF_FILE = path.join(__dirname, 'notif.json');
const LOG_FILE = '/var/log/hazi-tunnel.log';

app.use(cors());
app.use(express.json());

// --- HELPER FUNCTIONS ---
function loadJson(file) {
    try {
        if (!fs.existsSync(file)) return null; 
        return JSON.parse(fs.readFileSync(file, 'utf8'));
    } catch (e) { return null; }
}

function saveJson(file, data) {
    fs.writeFileSync(file, JSON.stringify(data, null, 2));
}

// --- LOGIKA SLOT (FACTORY FUNCTION) ---
function createNewSlots() {
    return { "10:00": "available", "11:00": "available", "12:00": "available", "13:00": "available", "14:00": "available" };
}

// --- API ROUTES ---

// 1. CEK KESEHATAN SERVER
app.get('/health', (req, res) => res.json({ status: "ok" }));

// 2. SLOT SYSTEM
app.get('/slots', (req, res) => {
    const now = new Date();
    now.setHours(now.getHours() + 7); // WIB
    const defaultDate = now.toISOString().split('T')[0];
    const reqDate = req.query.date || defaultDate;
    
    let data = loadJson(DB_FILE) || {};

    // Buat slot baru jika tanggal belum ada
    if (!data[reqDate]) {
        data[reqDate] = createNewSlots();
        saveJson(DB_FILE, data);
    }
    
    res.set('Cache-Control', 'no-store, no-cache, must-revalidate, private');
    res.json({ date: reqDate, slots: data[reqDate] });
});

app.post('/slots', (req, res) => {
    const { date, time, status } = req.body;
    if(!date || !time || !status) return res.status(400).json({error: "Data incomplete"});

    let data = loadJson(DB_FILE) || {};
    if (!data[date]) data[date] = createNewSlots();

    data[date][time] = status;
    saveJson(DB_FILE, data);
    
    res.json({ success: true, date, slots: data[date] });
});

app.post('/reset', (req, res) => {
    const { date } = req.body;
    let data = loadJson(DB_FILE) || {};
    data[date] = createNewSlots(); 
    saveJson(DB_FILE, data);
    res.json({ success: true });
});

// 3. NOTIFICATION SYSTEM (FITUR BARU)
app.get('/notif', (req, res) => {
    const data = loadJson(NOTIF_FILE) || [];
    res.set('Cache-Control', 'no-store');
    res.json(data);
});

app.post('/notif', (req, res) => {
    const newData = req.body; // Array notifikasi dari admin
    saveJson(NOTIF_FILE, newData);
    res.json({ success: true, count: newData.length });
});

// 4. TUNNEL URL
app.get('/tunnel-url', (req, res) => {
    try {
        if (fs.existsSync(LOG_FILE)) {
            const content = fs.readFileSync(LOG_FILE, 'utf8');
            const match = content.match(/https:\/\/[a-zA-Z0-9-]+\.trycloudflare\.com/);
            res.json({ url: match ? match[0] : "Menunggu Cloudflare..." });
        } else { res.json({ url: "Log belum ada" }); }
    } catch (error) { res.json({ url: "Error log" }); }
});

// 5. ADMIN PANEL (Fallback)
app.get('/admin', (req, res) => res.sendFile(path.join(__dirname, 'admin-local.html')));

app.listen(PORT, () => console.log(`🚀 Server Running on ${PORT}`));
