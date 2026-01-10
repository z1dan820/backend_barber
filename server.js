const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const app = express();
const PORT = 3000;
const DB_FILE = path.join(__dirname, 'slots.json');
const LOG_FILE = '/var/log/hazi-tunnel.log';

app.use(cors());
app.use(express.json());

// --- LOGIKA UTAMA: FACTORY FUNCTION ---
function createNewSlots() {
    return {
        "10:00": "available", "11:00": "available", "12:00": "available", 
        "13:00": "available", "14:00": "available"
    };
}

function loadData() {
    try {
        if (!fs.existsSync(DB_FILE)) return {};
        return JSON.parse(fs.readFileSync(DB_FILE, 'utf8'));
    } catch (e) { return {}; }
}

function saveData(data) {
    fs.writeFileSync(DB_FILE, JSON.stringify(data, null, 2));
}

// --- API ROUTES ---

// 1. GET Slots
app.get('/slots', (req, res) => {
    // Default Tanggal = Hari Ini (WIB)
    const now = new Date();
    now.setHours(now.getHours() + 7);
    const defaultDate = now.toISOString().split('T')[0];
    
    const reqDate = req.query.date || defaultDate;
    let data = loadData();

    // JIKA TANGGAL BELUM ADA, BUAT BARU
    if (!data[reqDate]) {
        console.log(`[INFO] New slots created for: ${reqDate}`);
        data[reqDate] = createNewSlots();
        saveData(data);
    }
    
    // Header Anti Cache
    res.set('Cache-Control', 'no-store, no-cache, must-revalidate, private');
    res.json({ date: reqDate, slots: data[reqDate] });
});

// 2. UPDATE Slot
app.post('/slots', (req, res) => {
    const { date, time, status } = req.body;
    if(!date || !time || !status) return res.status(400).json({error: "Data incomplete"});

    const data = loadData();
    if (!data[date]) data[date] = createNewSlots();

    data[date][time] = status;
    saveData(data);
    
    res.json({ success: true, date, slots: data[date] });
});

// 3. RESET Slot
app.post('/reset', (req, res) => {
    const { date } = req.body;
    const data = loadData();
    data[date] = createNewSlots(); 
    saveData(data);
    res.json({ success: true });
});

// 4. URL Tunnel
app.get('/tunnel-url', (req, res) => {
    try {
        const log = fs.readFileSync(LOG_FILE, 'utf8');
        const match = log.match(/https:\/\/[a-zA-Z0-9-]+\.trycloudflare\.com/);
        res.json({ url: match ? match[0] : "Menunggu URL..." });
    } catch (e) { res.json({ url: "Log belum siap" }); }
});

// 5. Admin Panel
app.get('/admin', (req, res) => res.sendFile(path.join(__dirname, 'admin-local.html')));

app.listen(PORT, () => console.log(`🚀 Hazi Backend running on port ${PORT}`));
