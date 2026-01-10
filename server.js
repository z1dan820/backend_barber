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
// Membuat object baru setiap kali dipanggil (Kertas Bersih)
function createNewSlots() {
    return {
        "10:00": "available", "11:00": "available", "12:00": "available", 
        "13:00": "available", "14:00": "available"
    };
}

// Helper: Ambil tanggal hari ini (WIB)
function getTodayStr() {
    const now = new Date();
    now.setHours(now.getHours() + 7); // Offset WIB
    return now.toISOString().split('T')[0];
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

// Bersihkan data tanggal lampau agar file tidak berat
function cleanOldData(data) {
    const today = getTodayStr();
    let changed = false;
    Object.keys(data).forEach(date => {
        if (date < today) {
            delete data[date];
            changed = true;
        }
    });
    if (changed) saveData(data);
    return data;
}

// --- API ROUTES ---

app.get('/health', (req, res) => res.json({ status: "ok" }));

// 1. GET SLOTS (Multi Tanggal)
app.get('/slots', (req, res) => {
    let data = loadData();
    data = cleanOldData(data); 

    // Ambil tanggal dari query, atau default ke Hari Ini
    const reqDate = req.query.date || getTodayStr();

    // JIKA TANGGAL BELUM ADA, BUAT BARU
    if (!data[reqDate]) {
        console.log(`[INFO] New slots created for: ${reqDate}`);
        data[reqDate] = createNewSlots(); // <--- Pakai Factory Function
        saveData(data);
    }
    
    // Header Anti Cache
    res.set('Cache-Control', 'no-store, no-cache, must-revalidate, private');
    res.json({ date: reqDate, slots: data[reqDate] });
});

// 2. UPDATE SLOT
app.post('/slots', (req, res) => {
    const { date, time, status } = req.body;
    if(!date || !time || !status) return res.status(400).json({error: "Data incomplete"});

    const data = loadData();
    
    // Double check: kalau tanggal belum ada, buat dulu
    if (!data[date]) data[date] = createNewSlots();

    // Update status
    data[date][time] = status;
    saveData(data);
    
    res.json({ success: true, date, slots: data[date] });
});

// 3. RESET SLOT PER TANGGAL
app.post('/reset', (req, res) => {
    const { date } = req.body;
    if(!date) return res.status(400).json({error: "Date required"});

    const data = loadData();
    data[date] = createNewSlots(); // Timpa dengan object baru
    saveData(data);
    
    res.json({ success: true, message: `Slots for ${date} reset` });
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

// 5. ADMIN UI
app.get('/admin', (req, res) => res.sendFile(path.join(__dirname, 'admin-local.html')));

app.listen(PORT, () => console.log(`🚀 Hazi Backend running on port ${PORT}`));
