const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const app = express();
const PORT = 3000;
const DB_FILE = path.join(__dirname, 'slots.json');

app.use(cors()); // Allow all origins (penting untuk Vercel -> Cloudflare)
app.use(express.json());

// --- LOGIKA DATABASE SEDERHANA ---

// Template slot default
const defaultSlots = {
    "10:00": "available",
    "11:00": "available",
    "12:00": "available",
    "13:00": "available",
    "14:00": "available"
};

function getTodayDate() {
    return new Date().toISOString().split('T')[0]; // Format YYYY-MM-DD
}

function loadData() {
    try {
        if (!fs.existsSync(DB_FILE)) throw new Error('No file');
        const data = JSON.parse(fs.readFileSync(DB_FILE));
        
        // Cek apakah tanggal data masih hari ini
        if (data.date !== getTodayDate()) {
            console.log("Hari baru terdeteksi. Reset slot.");
            return resetData();
        }
        return data;
    } catch (e) {
        return resetData();
    }
}

function resetData() {
    const newData = {
        date: getTodayDate(),
        slots: { ...defaultSlots }
    };
    saveData(newData);
    return newData;
}

function saveData(data) {
    fs.writeFileSync(DB_FILE, JSON.stringify(data, null, 2));
}

// --- ROUTES ---

// 1. Cek Kesehatan Server
app.get('/health', (req, res) => res.json({ status: "ok" }));

// 2. Ambil Slot (Public)
app.get('/slots', (req, res) => {
    const data = loadData();
    res.json(data);
});

// 3. Update Slot (Admin Local Only)
app.post('/slots', (req, res) => {
    const { time, status } = req.body;
    const data = loadData();
    
    if (data.slots[time]) {
        data.slots[time] = status; // 'available' or 'booked'
        saveData(data);
        res.json({ success: true, data });
    } else {
        res.status(400).json({ error: "Slot not found" });
    }
});

// 4. Manual Reset (Admin Local Only)
app.post('/reset', (req, res) => {
    const data = resetData();
    res.json({ success: true, message: "Slots reset manually", data });
});

// 5. Serve Admin UI Lokal
app.get('/admin', (req, res) => {
    res.sendFile(path.join(__dirname, 'admin-local.html'));
});

// Start Server
app.listen(PORT, () => {
    console.log(`💈 Hazi Backend running on port ${PORT}`);
    // Trigger loadData on start to ensure date is correct
    loadData();
});
      
