const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const app = express();
const PORT = 3000;
const DB_FILE = path.join(__dirname, 'slots.json');
const LOG_FILE = '/var/log/hazi-tunnel.log'; // Lokasi log cloudflared

app.use(cors());
app.use(express.json());

// --- DATA & LOGIC ---
const defaultSlots = { "10:00": "available", "11:00": "available", "12:00": "available", "13:00": "available", "14:00": "available" };

function getTodayDate() { return new Date().toISOString().split('T')[0]; }

function loadData() {
    try {
        if (!fs.existsSync(DB_FILE)) throw new Error('No file');
        const data = JSON.parse(fs.readFileSync(DB_FILE));
        if (data.date !== getTodayDate()) return resetData();
        return data;
    } catch (e) { return resetData(); }
}

function resetData() {
    const newData = { date: getTodayDate(), slots: { ...defaultSlots } };
    saveData(newData);
    return newData;
}

function saveData(data) { fs.writeFileSync(DB_FILE, JSON.stringify(data, null, 2)); }

// --- ROUTES ---

app.get('/health', (req, res) => res.json({ status: "ok" }));
app.get('/slots', (req, res) => res.json(loadData()));

app.post('/slots', (req, res) => {
    const { time, status } = req.body;
    const data = loadData();
    if (data.slots[time]) {
        data.slots[time] = status;
        saveData(data);
        res.json({ success: true, data });
    } else {
        res.status(400).json({ error: "Slot not found" });
    }
});

app.post('/reset', (req, res) => {
    res.json({ success: true, data: resetData() });
});

// FITUR BARU: Ambil URL Cloudflare dari log
app.get('/tunnel-url', (req, res) => {
    try {
        if (fs.existsSync(LOG_FILE)) {
            const logContent = fs.readFileSync(LOG_FILE, 'utf8');
            // Regex mencari pola https://xxxx.trycloudflare.com
            const match = logContent.match(/https:\/\/[a-zA-Z0-9-]+\.trycloudflare\.com/);
            if (match) {
                res.json({ url: match[0] });
            } else {
                res.json({ url: "Menunggu Cloudflare..." });
            }
        } else {
            res.json({ url: "Log file belum ada" });
        }
    } catch (error) {
        res.json({ url: "Error membaca log" });
    }
});

// Serve Admin UI
app.get('/admin', (req, res) => res.sendFile(path.join(__dirname, 'admin-local.html')));

app.listen(PORT, () => {
    console.log(`💈 Hazi Backend running on port ${PORT}`);
    loadData();
});
    
