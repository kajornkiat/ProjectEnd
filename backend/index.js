const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const bodyParser = require('body-parser');
const bcrypt = require("bcryptjs");
const { Pool } = require('pg');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const jwt = require('jsonwebtoken');
const fs = require('fs');
require("dotenv").config();

const app = express();
const server = http.createServer(app); // สร้างเซิร์ฟเวอร์ HTTP
const io = new Server(server, {
    cors: { origin: '*' } // อนุญาตทุก origin
});

const port = 3000;

const pool = new Pool({
    user: 'user',
    host: 'db',
    database: 'mydb',
    password: 'mosswn1234',
    port: 5432,
});

const SECRET_KEY = 'your-secret-key'; // กำหนด SECRET_KEY สำหรับ JWT

app.use(bodyParser.json());
app.use(cors({
    origin: '*',
    methods: 'GET,POST,DELETE',
    credentials: true
}));


// Middleware สำหรับตรวจสอบ token
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    if (!token) {
        return res.status(401).json({ error: "No token provided" });
    }

    jwt.verify(token, SECRET_KEY, (err, user) => {
        if (err) {
            console.error("JWT verification failed:", err);
            return res.status(403).json({ error: "Invalid token" });
        }
        req.user = user;
        console.log("Authenticated User:", user);
        next();
    });
};


// Login Endpoint
app.post('/api/login', async (req, res) => {
    const { username, password } = req.body;
    const query = 'SELECT id, password, status FROM users WHERE username = $1';
    try {
        const result = await pool.query(query, [username]);
        if (result.rows.length > 0) {
            const user = result.rows[0];
            const validPassword = await bcrypt.compare(password, user.password);
            if (validPassword) {
                const token = jwt.sign({ id: user.id, status: user.status }, SECRET_KEY, { expiresIn: '1h' });
                res.json({ id: user.id, token, status: user.status });
            } else {
                res.status(401).json({ error: 'Invalid username or password' });
            }
        } else {
            res.status(401).json({ error: 'Invalid username or password' });
        }
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Server error' });
    }
});



// Signup Endpoint
app.post('/api/signup', async (req, res) => {
    const { username, password, email, fullname, gender, birthdate } = req.body;

    // ตรวจสอบ username และ password ด้วย regex
    const usernameRegex = /^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)[A-Za-z\d]{1,20}$/;
    const passwordRegex = /^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)[A-Za-z\d]{8,10}$/;

    if (!usernameRegex.test(username)) {
        return res.status(400).json({ message: 'Username must be 1-20 characters long and contain only letters or numbers.' });
    }

    if (!passwordRegex.test(password)) {
        return res.status(400).json({ message: 'Password must be 8-10 characters long and contain only letters or numbers.' });
    }

    try {
        // ตรวจสอบว่า username หรือ email ซ้ำหรือไม่
        const checkUser = await pool.query(
            'SELECT * FROM users WHERE username = $1 OR email = $2',
            [username, email]
        );

        if (checkUser.rows.length > 0) {
            return res.status(400).json({ message: 'Username or Email already exists. Please choose a different one.' });
        }

        const hashedPassword = bcrypt.hashSync(password, 10);
        const defaultStatus = 'user';

        // เพิ่มผู้ใช้ใหม่ลงฐานข้อมูล
        const result = await pool.query(
            'INSERT INTO users (username, password, email, fullname, gender, birthdate, status) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *',
            [username, hashedPassword, email, fullname, gender, birthdate, defaultStatus]
        );

        res.json(result.rows[0]);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/users/all', async (req, res) => {
    try {
        const result = await pool.query("SELECT id, username, fullname, profile_image, background_image, status FROM users");
        res.json(result.rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: "Server error" });
    }
});

app.put('/api/users/update-status', async (req, res) => {
    const { userId, status } = req.body;
    if (!userId || !status) {
        return res.status(400).json({ error: "Missing data" });
    }

    try {
        await pool.query("UPDATE users SET status = $1 WHERE id = $2", [status, userId]);
        res.json({ success: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: "Failed to update status" });
    }
});


app.delete('/api/users/delete', async (req, res) => {
    const { userId } = req.body;
    if (!userId) {
        return res.status(400).json({ error: 'Missing userId' });
    }

    try {
        await pool.query('DELETE FROM users WHERE id = $1', [userId]);
        res.json({ message: 'User deleted successfully' });
    } catch (error) {
        console.error('Error deleting user:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});


// Profile Endpoint
app.get('/profile/:id', authenticateToken, async (req, res) => {
    const { id } = req.params;
    try {
        const result = await pool.query('SELECT * FROM users WHERE id = $1', [id]);
        if (result.rows.length > 0) {
            res.status(200).json(result.rows[0]);
        } else {
            res.status(404).json({ error: 'Profile not found' });
        }
    } catch (error) {
        console.error('Database error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

app.get('/friends/:id', authenticateToken, async (req, res) => {
    const { id } = req.params;
    try {
        const result = await pool.query(
            `SELECT u.id, u.fullname, u.profile_image, u.background_image
             FROM friends f
             JOIN users u ON 
                 (f.sender_id = u.id AND f.receiver_id = $1) OR
                 (f.receiver_id = u.id AND f.sender_id = $1)
             WHERE f.status = 'accepted'`,
            [id]
        );

        res.status(200).json(result.rows);
    } catch (error) {
        console.error('Database error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Serve uploaded files
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Upload Profile Image
const storage = multer.diskStorage({
    destination: './uploads/',
    filename: (req, file, cb) => {
        cb(null, Date.now() + path.extname(file.originalname));
    },
});
const upload = multer({ storage });

app.post('/profile', upload.fields([{ name: 'profile_image' }, { name: 'background_image' }]), authenticateToken, async (req, res) => {
    const { name, id: userId } = req.body;

    if (!userId) {
        return res.status(400).json({ message: 'User ID is required' });
    }

    try {
        const currentUserResult = await pool.query('SELECT * FROM users WHERE id = $1', [userId]);
        if (currentUserResult.rows.length === 0) {
            return res.status(404).json({ message: 'User not found' });
        }
        const currentUser = currentUserResult.rows[0];

        const updatedName = name || currentUser.fullname;
        const updatedProfileImage = req.files['profile_image']
            ? `/uploads/${req.files['profile_image'][0].filename}`
            : currentUser.profile_image;
        const updatedBackgroundImage = req.files['background_image']
            ? `/uploads/${req.files['background_image'][0].filename}`
            : currentUser.background_image;

        const result = await pool.query(
            `UPDATE users SET fullname = $1, profile_image = $2, background_image = $3 WHERE id = $4 RETURNING *`,
            [updatedName, updatedProfileImage, updatedBackgroundImage, userId]
        );

        res.json({
            message: 'Profile updated successfully',
            profile: result.rows[0],
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

//food
const foodStorage = multer.diskStorage({
    destination: path.join(__dirname, 'foodimage'), // Save files to foodimage folder
    filename: (req, file, cb) => {
        cb(null, Date.now() + '-' + Math.round(Math.random() * 1000) + path.extname(file.originalname));
    },
});

const foodUpload = multer({ storage: foodStorage });

// ✅ อัปเดตให้รองรับการอัปโหลดรูปสูงสุดไม่จำกัด
app.post('/api/food', foodUpload.array('images'), async (req, res) => {
    const { province, name, description, latitude, longitude, price, phone, placetyp } = req.body;

    if (!province || !name || !latitude || !longitude) {
        return res.status(400).json({ error: 'Province, Name, Latitude, and Longitude are required.' });
    }

    // ดึง path ของรูปทั้งหมดที่อัปโหลด
    const imagePaths = req.files.map(file => `/foodimage/${file.filename}`);

    try {
        const result = await pool.query(
            `INSERT INTO food (province, name, images, description, latitude, longitude, price, phone, placetyp) 
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *`,
            [province, name, imagePaths, description, latitude, longitude, price, phone, placetyp]
        );
        res.status(201).json(result.rows[0]);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.put('/api/food', foodUpload.array('images'), async (req, res) => {
    const { place_id, province, name, description, latitude, longitude, price, phone, placetyp } = req.body;

    if (!place_id) {
        return res.status(400).json({ error: 'Place ID is required.' });
    }

    try {
        // ดึงข้อมูลปัจจุบันของร้านอาหารก่อน
        const existingFood = await pool.query('SELECT images FROM food WHERE id = $1', [place_id]);
        if (existingFood.rows.length === 0) {
            return res.status(404).json({ error: 'Food not found.' });
        }

        let imagePaths = existingFood.rows[0].images || []; // ดึงรูปที่มีอยู่

        // ถ้ามีการอัปโหลดรูปใหม่ ให้เพิ่มรูปใหม่เข้าไปใน array
        if (req.files.length > 0) {
            const newImages = req.files.map(file => `/foodimage/${file.filename}`);
            imagePaths = [...imagePaths, ...newImages]; // รวมรูปเดิมและรูปใหม่
        }

        // อัปเดตข้อมูลในฐานข้อมูล
        const result = await pool.query(
            `UPDATE food 
             SET province = $1, name = $2, images = $3, description = $4, latitude = $5, longitude = $6, 
                 price = $7, phone = $8, placetyp = $9
             WHERE id = $10 RETURNING *`,
            [
                province,
                name,
                imagePaths, // ✅ ใช้เป็น Array ตรงๆ เพราะ PostgreSQL รองรับ TEXT[]
                description,
                parseFloat(latitude),  // ✅ แปลง latitude เป็นตัวเลข
                parseFloat(longitude), // ✅ แปลง longitude เป็นตัวเลข
                price,
                phone,
                placetyp,
                place_id
            ]
        );

        res.status(200).json(result.rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.message });
    }
});


app.get('/api/food', async (req, res) => {
    try {
        const { province, name, placetyp, price, phone } = req.query;
        let query = 'SELECT * FROM food';
        let conditions = [];
        let values = [];

        // เพิ่มเงื่อนไขการค้นหา
        if (province) {
            conditions.push(`LOWER(province) LIKE $${values.length + 1}`);
            values.push(`%${province.toLowerCase()}%`);
        }
        if (name) {
            conditions.push(`LOWER(name) LIKE $${values.length + 1}`);
            values.push(`%${name.toLowerCase()}%`);
        }
        if (placetyp) {
            conditions.push(`LOWER(placetyp) LIKE $${values.length + 1}`);
            values.push(`%${placetyp.toLowerCase()}%`);
        }
        if (price) {
            conditions.push(`price = $${values.length + 1}`);
            values.push(price);
        }
        if (phone) {
            conditions.push(`phone = $${values.length + 1}`);
            values.push(phone);
        }

        if (conditions.length > 0) {
            query += ' WHERE ' + conditions.join(' OR '); // ใช้ OR เพื่อให้ค้นหาได้หลากหลาย
        }

        const result = await pool.query(query, values);
        let foodData = result.rows;

        // คำนวณค่าเฉลี่ย rating และจำนวนรีวิวสำหรับแต่ละ food
        for (let i = 0; i < foodData.length; i++) {
            const food = foodData[i];

            const statsQuery = await pool.query(
                `SELECT COALESCE(AVG(rating), 0) AS average_rating, COUNT(*) AS review_count 
                 FROM reviews 
                 WHERE category = 'food' AND place_id = $1`,
                [food.id]
            );

            food.averageRating = parseFloat(statsQuery.rows[0].average_rating);
            food.reviewCount = parseInt(statsQuery.rows[0].review_count);
        }

        // **เรียงลำดับข้อมูล**: ตรงมากที่สุดขึ้นก่อน
        foodData.sort((a, b) => {
            let scoreA = (province && a.province.toLowerCase().startsWith(province.toLowerCase()) ? 1 : 0) +
                (name && a.name.toLowerCase().startsWith(name.toLowerCase()) ? 1 : 0);
            let scoreB = (province && b.province.toLowerCase().startsWith(province.toLowerCase()) ? 1 : 0) +
                (name && b.name.toLowerCase().startsWith(name.toLowerCase()) ? 1 : 0);
            return scoreB - scoreA;
        });

        res.json(foodData);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

app.delete('/api/food/:id', async (req, res) => {
    const { id } = req.params;

    try {
        await pool.query('DELETE FROM food WHERE id = $1', [id]);
        res.status(200).json({ message: 'Place deleted successfully' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/food/:id', async (req, res) => {
    const { id } = req.params;

    try {
        const result = await pool.query('SELECT * FROM food WHERE id = $1', [id]);
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Food not found.' });
        }

        res.status(200).json(result.rows[0]);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.delete('/api/food/:id/images', async (req, res) => {
    const { id } = req.params;
    const { imageUrl } = req.body; // URL ของรูปที่ต้องการลบ

    try {
        // ดึงข้อมูลรูปปัจจุบัน
        const existingFood = await pool.query('SELECT images FROM food WHERE id = $1', [id]);
        if (existingFood.rows.length === 0) {
            return res.status(404).json({ error: 'Food not found.' });
        }

        // ลบรูปที่ระบุออกจาก array
        const updatedImages = existingFood.rows[0].images.filter(img => img !== imageUrl);

        // อัปเดตตาราง
        await pool.query('UPDATE food SET images = $1 WHERE id = $2', [updatedImages, id]);

        res.status(200).json({ message: 'Image deleted successfully.' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.put('/api/food/:id/images', foodUpload.array('images'), async (req, res) => {
    const { id } = req.params;

    try {
        // ดึงข้อมูลรูปปัจจุบัน
        const existingFood = await pool.query('SELECT images FROM food WHERE id = $1', [id]);
        if (existingFood.rows.length === 0) {
            return res.status(404).json({ error: 'Food not found.' });
        }

        // เพิ่มรูปใหม่เข้าไปใน array
        const newImages = req.files.map(file => `/foodimage/${file.filename}`);
        const updatedImages = [...existingFood.rows[0].images, ...newImages];

        // อัปเดตตาราง
        await pool.query('UPDATE food SET images = $1 WHERE id = $2', [updatedImages, id]);

        res.status(200).json({ message: 'Images added successfully.', images: updatedImages });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.use('/foodimage', express.static(path.join(__dirname, 'foodimage')));

//hotel
const hotelStorage = multer.diskStorage({
    destination: path.join(__dirname, 'hotelimage'), // Save files to hotelimage folder
    filename: (req, file, cb) => {
        cb(null, Date.now() + '-' + Math.round(Math.random() * 1000) + path.extname(file.originalname));
    },
});

const hotelUpload = multer({ storage: hotelStorage });

// ✅ อัปเดตให้รองรับการอัปโหลดรูปสูงสุดไม่จำกัด
app.post('/api/hotel', hotelUpload.array('images'), async (req, res) => {
    const { province, name, description, latitude, longitude, price, phone, placetyp } = req.body;

    if (!province || !name || !latitude || !longitude) {
        return res.status(400).json({ error: 'Province, Name, Latitude, and Longitude are required.' });
    }

    // ดึง path ของรูปทั้งหมดที่อัปโหลด
    const imagePaths = req.files.map(file => `/hotelimage/${file.filename}`);

    try {
        const result = await pool.query(
            `INSERT INTO hotel (province, name, images, description, latitude, longitude, price, phone, placetyp) 
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *`,
            [province, name, imagePaths, description, latitude, longitude, price, phone, placetyp]
        );
        res.status(201).json(result.rows[0]);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.put('/api/hotel', hotelUpload.array('images'), async (req, res) => {
    const { place_id, province, name, description, latitude, longitude, price, phone, placetyp } = req.body;

    if (!place_id) {
        return res.status(400).json({ error: 'Place ID is required.' });
    }

    try {
        // ดึงข้อมูลปัจจุบันของร้านอาหารก่อน
        const existinghotel = await pool.query('SELECT images FROM hotel WHERE id = $1', [place_id]);
        if (existinghotel.rows.length === 0) {
            return res.status(404).json({ error: 'hotel not found.' });
        }

        let imagePaths = existinghotel.rows[0].images || []; // ดึงรูปที่มีอยู่

        // ถ้ามีการอัปโหลดรูปใหม่ ให้เพิ่มรูปใหม่เข้าไปใน array
        if (req.files.length > 0) {
            const newImages = req.files.map(file => `/hotelimage/${file.filename}`);
            imagePaths = [...imagePaths, ...newImages]; // รวมรูปเดิมและรูปใหม่
        }

        // อัปเดตข้อมูลในฐานข้อมูล
        const result = await pool.query(
            `UPDATE hotel 
             SET province = $1, name = $2, images = $3, description = $4, latitude = $5, longitude = $6, 
                 price = $7, phone = $8, placetyp = $9
             WHERE id = $10 RETURNING *`,
            [
                province,
                name,
                imagePaths, // ✅ ใช้เป็น Array ตรงๆ เพราะ PostgreSQL รองรับ TEXT[]
                description,
                parseFloat(latitude),  // ✅ แปลง latitude เป็นตัวเลข
                parseFloat(longitude), // ✅ แปลง longitude เป็นตัวเลข
                price,
                phone,
                placetyp,
                place_id
            ]
        );

        res.status(200).json(result.rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.message });
    }
});


app.get('/api/hotel', async (req, res) => {
    try {
        const { province, name, placetyp, price, phone } = req.query;
        let query = 'SELECT * FROM hotel';
        let conditions = [];
        let values = [];

        // เพิ่มเงื่อนไขการค้นหา
        if (province) {
            conditions.push(`LOWER(province) LIKE $${values.length + 1}`);
            values.push(`%${province.toLowerCase()}%`);
        }
        if (name) {
            conditions.push(`LOWER(name) LIKE $${values.length + 1}`);
            values.push(`%${name.toLowerCase()}%`);
        }
        if (placetyp) {
            conditions.push(`LOWER(placetyp) LIKE $${values.length + 1}`);
            values.push(`%${placetyp.toLowerCase()}%`);
        }
        if (price) {
            conditions.push(`price = $${values.length + 1}`);
            values.push(price);
        }
        if (phone) {
            conditions.push(`phone = $${values.length + 1}`);
            values.push(phone);
        }

        if (conditions.length > 0) {
            query += ' WHERE ' + conditions.join(' OR '); // ใช้ OR เพื่อให้ค้นหาได้หลากหลาย
        }

        const result = await pool.query(query, values);
        let hotelData = result.rows;

        // คำนวณค่าเฉลี่ย rating และจำนวนรีวิวสำหรับแต่ละ hotel
        for (let i = 0; i < hotelData.length; i++) {
            const hotel = hotelData[i];

            const statsQuery = await pool.query(
                `SELECT COALESCE(AVG(rating), 0) AS average_rating, COUNT(*) AS review_count 
                 FROM reviews 
                 WHERE category = 'hotel' AND place_id = $1`,
                [hotel.id]
            );

            hotel.averageRating = parseFloat(statsQuery.rows[0].average_rating);
            hotel.reviewCount = parseInt(statsQuery.rows[0].review_count);
        }

        // **เรียงลำดับข้อมูล**: ตรงมากที่สุดขึ้นก่อน
        hotelData.sort((a, b) => {
            let scoreA = (province && a.province.toLowerCase().startsWith(province.toLowerCase()) ? 1 : 0) +
                (name && a.name.toLowerCase().startsWith(name.toLowerCase()) ? 1 : 0);
            let scoreB = (province && b.province.toLowerCase().startsWith(province.toLowerCase()) ? 1 : 0) +
                (name && b.name.toLowerCase().startsWith(name.toLowerCase()) ? 1 : 0);
            return scoreB - scoreA;
        });

        res.json(hotelData);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

app.delete('/api/hotel/:id', async (req, res) => {
    const { id } = req.params;

    try {
        await pool.query('DELETE FROM hotel WHERE id = $1', [id]);
        res.status(200).json({ message: 'Place deleted successfully' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/hotel/:id', async (req, res) => {
    const { id } = req.params;

    try {
        const result = await pool.query('SELECT * FROM hotel WHERE id = $1', [id]);
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'hotel not found.' });
        }

        res.status(200).json(result.rows[0]);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.delete('/api/hotel/:id/images', async (req, res) => {
    const { id } = req.params;
    const { imageUrl } = req.body; // URL ของรูปที่ต้องการลบ

    try {
        // ดึงข้อมูลรูปปัจจุบัน
        const existinghotel = await pool.query('SELECT images FROM hotel WHERE id = $1', [id]);
        if (existinghotel.rows.length === 0) {
            return res.status(404).json({ error: 'hotel not found.' });
        }

        // ลบรูปที่ระบุออกจาก array
        const updatedImages = existinghotel.rows[0].images.filter(img => img !== imageUrl);

        // อัปเดตตาราง
        await pool.query('UPDATE hotel SET images = $1 WHERE id = $2', [updatedImages, id]);

        res.status(200).json({ message: 'Image deleted successfully.' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.put('/api/hotel/:id/images', hotelUpload.array('images'), async (req, res) => {
    const { id } = req.params;

    try {
        // ดึงข้อมูลรูปปัจจุบัน
        const existinghotel = await pool.query('SELECT images FROM hotel WHERE id = $1', [id]);
        if (existinghotel.rows.length === 0) {
            return res.status(404).json({ error: 'hotel not found.' });
        }

        // เพิ่มรูปใหม่เข้าไปใน array
        const newImages = req.files.map(file => `/hotelimage/${file.filename}`);
        const updatedImages = [...existinghotel.rows[0].images, ...newImages];

        // อัปเดตตาราง
        await pool.query('UPDATE hotel SET images = $1 WHERE id = $2', [updatedImages, id]);

        res.status(200).json({ message: 'Images added successfully.', images: updatedImages });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.use('/hotelimage', express.static(path.join(__dirname, 'hotelimage')));

//tourist
const touristStorage = multer.diskStorage({
    destination: path.join(__dirname, 'touristimage'), // Save files to touristimage folder
    filename: (req, file, cb) => {
        cb(null, Date.now() + '-' + Math.round(Math.random() * 1000) + path.extname(file.originalname));
    },
});

const touristUpload = multer({ storage: touristStorage });

// ✅ อัปเดตให้รองรับการอัปโหลดรูปสูงสุดไม่จำกัด
app.post('/api/tourist', touristUpload.array('images'), async (req, res) => {
    const { province, name, description, latitude, longitude, price, phone, placetyp } = req.body;

    if (!province || !name || !latitude || !longitude) {
        return res.status(400).json({ error: 'Province, Name, Latitude, and Longitude are required.' });
    }

    // ดึง path ของรูปทั้งหมดที่อัปโหลด
    const imagePaths = req.files.map(file => `/touristimage/${file.filename}`);

    try {
        const result = await pool.query(
            `INSERT INTO tourist (province, name, images, description, latitude, longitude, price, phone, placetyp) 
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *`,
            [province, name, imagePaths, description, latitude, longitude, price, phone, placetyp]
        );
        res.status(201).json(result.rows[0]);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.put('/api/tourist', touristUpload.array('images'), async (req, res) => {
    const { place_id, province, name, description, latitude, longitude, price, phone, placetyp } = req.body;

    if (!place_id) {
        return res.status(400).json({ error: 'Place ID is required.' });
    }

    try {
        // ดึงข้อมูลปัจจุบันของร้านอาหารก่อน
        const existingtourist = await pool.query('SELECT images FROM tourist WHERE id = $1', [place_id]);
        if (existingtourist.rows.length === 0) {
            return res.status(404).json({ error: 'tourist not found.' });
        }

        let imagePaths = existingtourist.rows[0].images || []; // ดึงรูปที่มีอยู่

        // ถ้ามีการอัปโหลดรูปใหม่ ให้เพิ่มรูปใหม่เข้าไปใน array
        if (req.files.length > 0) {
            const newImages = req.files.map(file => `/touristimage/${file.filename}`);
            imagePaths = [...imagePaths, ...newImages]; // รวมรูปเดิมและรูปใหม่
        }

        // อัปเดตข้อมูลในฐานข้อมูล
        const result = await pool.query(
            `UPDATE tourist 
             SET province = $1, name = $2, images = $3, description = $4, latitude = $5, longitude = $6, 
                 price = $7, phone = $8, placetyp = $9
             WHERE id = $10 RETURNING *`,
            [
                province,
                name,
                imagePaths, // ✅ ใช้เป็น Array ตรงๆ เพราะ PostgreSQL รองรับ TEXT[]
                description,
                parseFloat(latitude),  // ✅ แปลง latitude เป็นตัวเลข
                parseFloat(longitude), // ✅ แปลง longitude เป็นตัวเลข
                price,
                phone,
                placetyp,
                place_id
            ]
        );

        res.status(200).json(result.rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.message });
    }
});


app.get('/api/tourist', async (req, res) => {
    try {
        const { province, name, placetyp, price, phone } = req.query;
        let query = 'SELECT * FROM tourist';
        let conditions = [];
        let values = [];

        // เพิ่มเงื่อนไขการค้นหา
        if (province) {
            conditions.push(`LOWER(province) LIKE $${values.length + 1}`);
            values.push(`%${province.toLowerCase()}%`);
        }
        if (name) {
            conditions.push(`LOWER(name) LIKE $${values.length + 1}`);
            values.push(`%${name.toLowerCase()}%`);
        }
        if (placetyp) {
            conditions.push(`LOWER(placetyp) LIKE $${values.length + 1}`);
            values.push(`%${placetyp.toLowerCase()}%`);
        }
        if (price) {
            conditions.push(`price = $${values.length + 1}`);
            values.push(price);
        }
        if (phone) {
            conditions.push(`phone = $${values.length + 1}`);
            values.push(phone);
        }

        if (conditions.length > 0) {
            query += ' WHERE ' + conditions.join(' OR '); // ใช้ OR เพื่อให้ค้นหาได้หลากหลาย
        }

        const result = await pool.query(query, values);
        let touristData = result.rows;

        // คำนวณค่าเฉลี่ย rating และจำนวนรีวิวสำหรับแต่ละ tourist
        for (let i = 0; i < touristData.length; i++) {
            const tourist = touristData[i];

            const statsQuery = await pool.query(
                `SELECT COALESCE(AVG(rating), 0) AS average_rating, COUNT(*) AS review_count 
                 FROM reviews 
                 WHERE category = 'tourist' AND place_id = $1`,
                [tourist.id]
            );

            tourist.averageRating = parseFloat(statsQuery.rows[0].average_rating);
            tourist.reviewCount = parseInt(statsQuery.rows[0].review_count);
        }

        // **เรียงลำดับข้อมูล**: ตรงมากที่สุดขึ้นก่อน
        touristData.sort((a, b) => {
            let scoreA = (province && a.province.toLowerCase().startsWith(province.toLowerCase()) ? 1 : 0) +
                (name && a.name.toLowerCase().startsWith(name.toLowerCase()) ? 1 : 0);
            let scoreB = (province && b.province.toLowerCase().startsWith(province.toLowerCase()) ? 1 : 0) +
                (name && b.name.toLowerCase().startsWith(name.toLowerCase()) ? 1 : 0);
            return scoreB - scoreA;
        });

        res.json(touristData);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

app.delete('/api/tourist/:id', async (req, res) => {
    const { id } = req.params;

    try {
        await pool.query('DELETE FROM tourist WHERE id = $1', [id]);
        res.status(200).json({ message: 'Place deleted successfully' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/tourist/:id', async (req, res) => {
    const { id } = req.params;

    try {
        const result = await pool.query('SELECT * FROM tourist WHERE id = $1', [id]);
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'tourist not found.' });
        }

        res.status(200).json(result.rows[0]);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.delete('/api/tourist/:id/images', async (req, res) => {
    const { id } = req.params;
    const { imageUrl } = req.body; // URL ของรูปที่ต้องการลบ

    try {
        // ดึงข้อมูลรูปปัจจุบัน
        const existingtourist = await pool.query('SELECT images FROM tourist WHERE id = $1', [id]);
        if (existingtourist.rows.length === 0) {
            return res.status(404).json({ error: 'tourist not found.' });
        }

        // ลบรูปที่ระบุออกจาก array
        const updatedImages = existingtourist.rows[0].images.filter(img => img !== imageUrl);

        // อัปเดตตาราง
        await pool.query('UPDATE tourist SET images = $1 WHERE id = $2', [updatedImages, id]);

        res.status(200).json({ message: 'Image deleted successfully.' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.put('/api/tourist/:id/images', touristUpload.array('images'), async (req, res) => {
    const { id } = req.params;

    try {
        // ดึงข้อมูลรูปปัจจุบัน
        const existingtourist = await pool.query('SELECT images FROM tourist WHERE id = $1', [id]);
        if (existingtourist.rows.length === 0) {
            return res.status(404).json({ error: 'tourist not found.' });
        }

        // เพิ่มรูปใหม่เข้าไปใน array
        const newImages = req.files.map(file => `/touristimage/${file.filename}`);
        const updatedImages = [...existingtourist.rows[0].images, ...newImages];

        // อัปเดตตาราง
        await pool.query('UPDATE tourist SET images = $1 WHERE id = $2', [updatedImages, id]);

        res.status(200).json({ message: 'Images added successfully.', images: updatedImages });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.use('/touristimage', express.static(path.join(__dirname, 'touristimage')));

//post/feeds
// ตั้งค่า multer สำหรับการอัปโหลดไฟล์
const poststorage = multer.diskStorage({
    destination: (req, file, cb) => {
        const dir = path.join(__dirname, 'posts');
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir);
        }
        cb(null, dir);
    },
    filename: (req, file, cb) => {
        cb(null, Date.now() + path.extname(file.originalname));
    },
});

const postupload = multer({ storage: poststorage }).array('images'); // อนุญาตให้อัปโหลดได้สูงสุด ไม่จำกัด รูป

app.use('/posts', express.static(path.join(__dirname, 'posts')));

// POST: เพิ่มข้อมูลลงในตาราง post พร้อมเชื่อมโยง user_id จาก token
app.post('/api/posts', authenticateToken, postupload, async (req, res) => {
    const user_id = req.user.id;
    const { province, description } = req.body;
    const images = req.files ? req.files.map(file => file.filename) : []; // เก็บชื่อไฟล์รูปภาพเป็นอาร์เรย์

    try {
        // เพิ่มข้อมูลโพสต์ลงในตาราง post
        const result = await pool.query(
            `INSERT INTO post (user_id, province, description, images, date) 
            VALUES ($1, $2, $3, $4, NOW()) RETURNING *`,
            [user_id, province, description, images]
        );

        res.status(201).json(result.rows[0]);
    } catch (err) {
        console.error(err);
        res.status(500).send('เกิดข้อผิดพลาดในการเพิ่มข้อมูล');
    }
});

// GET: ดึงข้อมูลทั้งหมดจากตาราง post
app.get('/api/posts', async (req, res) => {
    try {
        const { province, user_id } = req.query;
        let query = `
            SELECT 
                post.post_id, 
                post.user_id, 
                post.province, 
                post.description, 
                post.images, -- ดึงคอลัมน์ images
                post.date,
                users.fullname, 
                users.profile_image,
                users.status,
                users.background_image,
                COALESCE(COUNT(comment.comment_id), 0)::INTEGER AS comment_count
            FROM post
            JOIN users ON post.user_id = users.id
            LEFT JOIN comment ON post.post_id = comment.post_id
        `;

        let values = [];
        let conditions = [];

        if (province) {
            conditions.push(`LOWER(post.province) LIKE $${values.length + 1}`);
            values.push(`%${province.toLowerCase()}%`);
        }

        if (user_id) {
            conditions.push(`post.user_id = $${values.length + 1}`);
            values.push(user_id);
        }

        if (conditions.length > 0) {
            query += ` WHERE ${conditions.join(' AND ')}`;
        }

        query += ` GROUP BY post.post_id, users.id ORDER BY post.date DESC`;

        const result = await pool.query(query, values);
        res.json(result.rows);
    } catch (err) {
        console.error('Database error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// DELETE: Admin ลบได้ทุกโพสต์ / User ลบได้แค่โพสต์ของตัวเอง
app.delete('/api/posts/:post_id', authenticateToken, async (req, res) => {
    const { post_id } = req.params;
    const user_id = req.user.id;     // user ID จาก token
    const user_status = req.user.status; // status จาก token (admin หรือ user)

    try {
        // ตรวจสอบว่าโพสต์นี้มีอยู่จริงหรือไม่
        const checkPost = await pool.query('SELECT user_id FROM post WHERE post_id = $1', [post_id]);

        if (checkPost.rows.length === 0) {
            return res.status(404).json({ error: "Post not found" });
        }

        const postOwnerId = checkPost.rows[0].user_id;

        // ✅ ถ้าเป็น admin ให้ลบได้ทุกโพสต์
        if (user_status === 'admin' || postOwnerId === user_id) {
            const result = await pool.query('DELETE FROM post WHERE post_id = $1 RETURNING *', [post_id]);

            if (result.rowCount > 0) {
                io.emit('delete_post', { post_id: parseInt(post_id) }); // 🔥 Broadcast ให้ทุก client ลบโพสต์
                return res.json({ message: "Post deleted successfully", post_id: post_id });
            } else {
                return res.status(500).json({ error: "Failed to delete post" });
            }
        } else {
            return res.status(403).json({ error: "You are not authorized to delete this post" });
        }

    } catch (error) {
        console.error("Error deleting post:", error);
        return res.status(500).json({ error: "Internal server error" });
    }
});



//comment
// ----------------------[ WebSockets ]----------------------
io.on('connection', (socket) => {
    console.log(`User connected: ${socket.id}`);

    socket.on('disconnect', () => {
        console.log(`User disconnected: ${socket.id}`);
    });
});

// POST: เพิ่มคอมเมนต์
app.post('/api/comments', authenticateToken, async (req, res) => {
    try {
        const { post_id, comment } = req.body;
        const user_comment_id = req.user.id;

        if (!post_id || !comment) {
            return res.status(400).json({ error: "Post ID and comment are required" });
        }

        const postExists = await pool.query("SELECT 1 FROM post WHERE post_id = $1", [post_id]);
        if (postExists.rowCount === 0) {
            return res.status(404).json({ error: "Post not found" });
        }

        const newComment = await pool.query(
            `INSERT INTO comment (post_id, user_comment_id, comment) 
             VALUES ($1, $2, $3) RETURNING *`,
            [post_id, user_comment_id, comment]
        );

        // 📡 แจ้งเตือนให้ทุก client อัปเดตคอมเมนต์ใหม่
        io.emit('new_comment', { post_id, comment: newComment.rows[0] });

        res.status(201).json(newComment.rows[0]);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: "Server error" });
    }
});

// GET: ดึงคอมเมนต์ของโพสต์
app.get('/api/comments/:post_id', async (req, res) => {
    try {
        const { post_id } = req.params;
        const comments = await pool.query(
            `SELECT c.comment_id, c.comment, c.date, 
                    u.id AS user_id, u.fullname, u.profile_image, u.background_image, u.status
             FROM comment c
             JOIN users u ON c.user_comment_id = u.id
             WHERE c.post_id = $1
             ORDER BY c.date ASC`,
            [post_id]
        );
        res.json(comments.rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: "Server error" });
    }
});

// DELETE: Admin ลบได้ทุกคอมเมนต์ / User ลบได้เฉพาะของตัวเอง
app.delete('/api/comments/:comment_id', authenticateToken, async (req, res) => {
    const comment_id = parseInt(req.params.comment_id, 10);
    const user_id = req.user.id;       // user ID จาก token
    const user_status = req.user.status; // status จาก token (admin หรือ user)

    try {
        // ตรวจสอบว่าคอมเมนต์นี้มีอยู่หรือไม่
        const comment = await pool.query('SELECT * FROM comment WHERE comment_id = $1', [comment_id]);

        if (comment.rows.length === 0) {
            return res.status(404).json({ message: "Comment not found" });
        }

        const commentOwnerId = comment.rows[0].user_comment_id;

        // ✅ ถ้าเป็น admin ให้ลบได้ทุกคอมเมนต์
        if (user_status === 'admin' || commentOwnerId === user_id) {
            await pool.query('DELETE FROM comment WHERE comment_id = $1', [comment_id]);

            // 📡 แจ้งเตือนให้ทุก client อัปเดตเมื่อมีการลบคอมเมนต์
            io.emit('delete_comment', { comment_id, post_id: comment.rows[0].post_id });

            return res.json({ message: "Comment deleted successfully" });
        } else {
            return res.status(403).json({ message: "You are not allowed to delete this comment" });
        }
    } catch (err) {
        console.error("Error deleting comment:", err.message);
        return res.status(500).json({ message: "Server error" });
    }
});


//reviews
// 📌 เพิ่มรีวิวใหม่
app.post('/api/reviews', authenticateToken, async (req, res) => {
    try {
        const { category, place_id, review, rating } = req.body;
        const user_id = req.user.id;

        console.log("Incoming review:", req.body);

        // ✅ ตรวจสอบค่า category
        const validCategories = ["food", "hotel", "tourist"];
        if (!validCategories.includes(category)) {
            return res.status(400).json({ error: "Invalid category" });
        }

        // ✅ ตรวจสอบว่ามีข้อมูลครบ
        if (!place_id || !review || rating === undefined) {
            return res.status(400).json({ error: 'Missing required fields' });
        }

        // ✅ ตรวจสอบค่า rating ให้เป็นตัวเลขเท่านั้น
        const ratingInt = Number(rating);
        if (isNaN(ratingInt) || ratingInt < 1 || ratingInt > 5) {
            return res.status(400).json({ error: 'Rating must be a number between 1 and 5' });
        }

        // ✅ ตรวจสอบว่า place_id มีอยู่ใน category ที่ถูกต้อง
        const placeExists = await pool.query(`SELECT id FROM ${category} WHERE id = $1`, [place_id]);
        if (placeExists.rowCount === 0) {
            return res.status(400).json({ error: `Place ID ${place_id} not found in ${category}` });
        }

        // ✅ เพิ่มรีวิว
        const newReview = await pool.query(
            `INSERT INTO reviews (user_id, category, place_id, review, rating) 
             VALUES ($1, $2, $3, $4, $5) RETURNING *`,
            [user_id, category, place_id, review, ratingInt]
        );

        io.emit('newReview', newReview.rows[0]);
        res.json(newReview.rows[0]);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Server error' });
    }
});


// 📌 ดึงรีวิวของสถานที่
app.get('/api/reviews/:category/:place_id', async (req, res) => {
    try {
        const { category, place_id } = req.params;

        // ✅ ตรวจสอบค่า category
        const validCategories = ["food", "hotel", "tourist"];
        if (!validCategories.includes(category)) {
            return res.status(400).json({ error: "Invalid category" });
        }

        // ✅ ตรวจสอบว่า place_id มีอยู่ใน category ที่ถูกต้อง
        const placeExists = await pool.query(`SELECT id FROM ${category} WHERE id = $1`, [place_id]);
        if (placeExists.rowCount === 0) {
            return res.status(404).json({ error: `Place ID ${place_id} not found in ${category}` });
        }

        // ✅ ดึงรีวิวทั้งหมด
        const reviewsQuery = await pool.query(
            `SELECT r.*, u.fullname, u.profile_image, u.background_image, u.status
             FROM reviews r 
             JOIN users u ON r.user_id = u.id 
             WHERE r.category = $1 AND r.place_id = $2 
             ORDER BY r.created_at DESC`,
            [category, place_id]
        );

        // ✅ คำนวณค่าเฉลี่ย rating และจำนวนรีวิว
        const statsQuery = await pool.query(
            `SELECT COALESCE(AVG(rating), 0) AS average_rating, COUNT(*) AS review_count 
             FROM reviews 
             WHERE category = $1 AND place_id = $2`,
            [category, place_id]
        );

        res.json({
            reviews: reviewsQuery.rows,
            averageRating: parseFloat(statsQuery.rows[0].average_rating),
            reviewCount: parseInt(statsQuery.rows[0].review_count)
        });

    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Server error' });
    }
});

// 📌 ดึงข้อมูลสถานที่โดยใช้ place_id
app.get('/api/place/:category/:place_id', async (req, res) => {
    try {
        const { category, place_id } = req.params;

        // ✅ ตรวจสอบค่า category
        const validCategories = ["food", "hotel", "tourist"];
        if (!validCategories.includes(category)) {
            return res.status(400).json({ error: "Invalid category" });
        }

        // ✅ ดึงข้อมูลสถานที่
        const placeQuery = await pool.query(
            `SELECT * FROM ${category} WHERE id = $1`,
            [place_id]
        );

        if (placeQuery.rowCount === 0) {
            return res.status(404).json({ error: `Place ID ${place_id} not found in ${category}` });
        }

        res.json(placeQuery.rows[0]);

    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Server error' });
    }
});


// 📌 ลบรีวิว (เฉพาะของตัวเอง)
app.delete('/api/reviews/:id', authenticateToken, async (req, res) => {
    try {
        const { id } = req.params;
        const user_id = req.user.id;

        // ✅ ตรวจสอบว่ารีวิวมีอยู่และเป็นของผู้ใช้ที่ร้องขอ
        const reviewCheck = await pool.query(
            "SELECT * FROM reviews WHERE id = $1 AND user_id = $2",
            [id, user_id]
        );

        if (reviewCheck.rowCount === 0) {
            return res.status(403).json({ error: "You can only delete your own reviews or review does not exist" });
        }

        // ✅ ลบรีวิว
        const review = await pool.query(
            "DELETE FROM reviews WHERE id = $1 AND user_id = $2 RETURNING *",
            [id, user_id]
        );

        io.emit('deleteReview', id);
        res.json({ message: "Review deleted successfully", deletedReview: review.rows[0] });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Server error' });
    }
});

// 📌 ลบรีวิว (เฉพาะ admin สามารถลบได้ทั้งหมด)
app.delete('/api/admin/reviews/:id', authenticateToken, async (req, res) => {
    try {
        const { id } = req.params;
        const user_id = req.user.id;

        // ✅ ตรวจสอบว่า user เป็น admin หรือไม่
        const adminCheck = await pool.query(
            "SELECT status FROM users WHERE id = $1",
            [user_id]
        );

        if (adminCheck.rowCount === 0 || adminCheck.rows[0].status !== 'admin') {
            return res.status(403).json({ error: "Only admins can delete any reviews" });
        }

        // ✅ ตรวจสอบว่ารีวิวมีอยู่หรือไม่
        const reviewCheck = await pool.query(
            "SELECT * FROM reviews WHERE id = $1",
            [id]
        );

        if (reviewCheck.rowCount === 0) {
            return res.status(404).json({ error: "Review not found" });
        }

        // ✅ ลบรีวิว
        const review = await pool.query(
            "DELETE FROM reviews WHERE id = $1 RETURNING *",
            [id]
        );

        io.emit('deleteReview', id);
        res.json({ message: "Review deleted successfully by admin", deletedReview: review.rows[0] });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Server error' });
    }
});


//add_freinds
// 🔎 API ค้นหาผู้ใช้ตาม fullname
app.get("/api/users/search", async (req, res) => {
    try {
        const { fullname } = req.query;
        const query = `
        SELECT id, fullname, profile_image, background_image, status
        FROM users 
        WHERE LOWER(fullname) LIKE LOWER($1) 
        LIMIT 10
      `;
        const users = await pool.query(query, [`%${fullname}%`]);
        res.json(users.rows);
    } catch (error) {
        console.error(error.message);
        res.status(500).send("Server error");
    }
});

//API ส่งคำขอเป็นเพื่อน
app.post('/api/friends/request', async (req, res) => {
    const { sender_id, receiver_id } = req.body;

    try {
        const existingRequest = await pool.query(
            'SELECT * FROM friends WHERE sender_id = $1 AND receiver_id = $2',
            [sender_id, receiver_id]
        );

        if (existingRequest.rows.length > 0) {
            return res.status(400).json({ message: 'Request already sent' });
        }

        await pool.query(
            'INSERT INTO friends (sender_id, receiver_id, friend_status) VALUES ($1, $2, $3)',
            [sender_id, receiver_id, 'pending']
        );
        res.json({ message: 'Friend request sent' });

    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

//API ยอมรับคำขอเป็นเพื่อน
app.put('/api/friends/accept', async (req, res) => {
    const { sender_id, receiver_id } = req.body;

    try {
        await pool.query(
            'UPDATE friends SET friend_status = $1 WHERE sender_id = $2 AND receiver_id = $3',
            ['accepted', sender_id, receiver_id]
        );
        res.json({ message: 'Friend request accepted' });

    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

//API เช็กสถานะเพื่อน
app.get('/api/friends/friend_status', async (req, res) => {
    const { user_id, friend_id } = req.query;

    try {
        const result = await pool.query(
            'SELECT friend_status FROM friends WHERE (sender_id = $1 AND receiver_id = $2) OR (sender_id = $2 AND receiver_id = $1)',
            [user_id, friend_id]
        );

        if (result.rows.length > 0) {
            const friendStatus = result.rows[0].friend_status; // ใช้ชื่อคอลัมน์ให้ถูกต้อง
            if (friendStatus) {
                res.json({ status: friendStatus }); // ส่งกลับ friend_status
            } else {
                res.json({ status: 'none' }); // หาก friend_status เป็น null
            }
        } else {
            res.json({ status: 'none' }); // หากไม่พบข้อมูล
        }
    } catch (error) {
        console.error("Error in /api/friends/friend_status:", error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

app.get('/api/friends/accepted/:userId', async (req, res) => {
    const userId = req.params.userId;

    try {
        const result = await pool.query(
            `SELECT 
          u.id, 
          u.fullname, 
          u.profile_image, 
          u.background_image, 
          u.status
         FROM 
          friends f
         JOIN 
          users u ON (f.sender_id = u.id OR f.receiver_id = u.id)
         WHERE 
          (f.sender_id = $1 OR f.receiver_id = $1) 
          AND f.friend_status = 'accepted' 
          AND u.id != $1`, // ตรวจสอบว่าไม่รวมผู้ใช้ปัจจุบัน
            [userId]
        );

        if (result.rows.length > 0) {
            res.json(result.rows);
        } else {
            res.json([]); // ส่งกลับอาร์เรย์ว่างหากไม่พบข้อมูล
        }
    } catch (error) {
        console.error("Error fetching accepted friends:", error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// API ดึงรายการคำขอเป็นเพื่อนของ receiver
app.get('/api/friends/requests', async (req, res) => {
    const { receiver_id } = req.query;

    try {
        const query = `
            SELECT u.id, u.fullname, u.profile_image, u.background_image
            FROM friends f
            JOIN users u ON f.sender_id = u.id
            WHERE f.receiver_id = $1 AND f.friend_status = 'pending'
        `;
        const result = await pool.query(query, [receiver_id]);

        res.json(result.rows);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// API ลบคำขอเป็นเพื่อนและลบเพื่อน
app.delete('/api/friends/delete', async (req, res) => {
    const { user_id, friend_id } = req.body;

    try {
        await pool.query(
            'DELETE FROM friends WHERE (sender_id = $1 AND receiver_id = $2) OR (sender_id = $2 AND receiver_id = $1)',
            [user_id, friend_id]
        );
        res.json({ message: 'Friend deleted successfully' });

    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});


// API ดึงจำนวนคำขอเป็นเพื่อนที่ pending
app.get('/api/friends/pending/count', async (req, res) => {
    const { user_id } = req.query;

    try {
        const { rows } = await pool.query(
            "SELECT COUNT(*) FROM friends WHERE receiver_id = $1 AND friend_status = 'pending'",
            [user_id]
        );

        res.json({ count: parseInt(rows[0].count, 10) });
    } catch (error) {
        console.error('Error fetching friend requests count:', error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

//api chat
app.get('/api/friends/search', async (req, res) => {
    const { userId, query } = req.query;

    if (!query) {
        return res.status(400).json({ error: 'Query is required' });
    }

    try {
        const searchQuery = `
            SELECT u.id, u.fullname, u.profile_image
            FROM users u
            JOIN friends f ON 
                (f.sender_id = u.id AND f.receiver_id = $1) OR
                (f.receiver_id = u.id AND f.sender_id = $1)
            WHERE u.fullname ILIKE $2 AND u.id != $1 AND f.friend_status = 'accepted'
            ORDER BY u.fullname;
        `;

        const result = await pool.query(searchQuery, [userId, `%${query}%`]);
        res.status(200).json(result.rows);
    } catch (error) {
        console.error('Error searching friends:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

//api messasge
io.on("connection", (socket) => {
    console.log("User connected:", socket.id);

    socket.on("joinRoom", (userId) => {
        socket.join(`user_${userId}`);
        console.log(`User ${userId} joined room user_${userId}`);
    });

    socket.on("sendMessage", async (data) => {
        console.log("📩 Received data:", data);
        const { senderId, receiverId, message, messageType } = data;

        try {
            const userQuery = "SELECT fullname, profile_image FROM users WHERE id = $1";
            const userResult = await pool.query(userQuery, [senderId]);

            const senderName = userResult.rows[0]?.fullname || "Unknown";
            const profileImage = userResult.rows[0]?.profile_image || "";

            const messageQuery = `
            INSERT INTO messages (sender_id, receiver_id, message, message_type) 
            VALUES ($1, $2, $3, $4) RETURNING id, created_at;
            `;

            const messageResult = await pool.query(messageQuery, [
                senderId,
                receiverId,
                message,
                messageType
            ]);

            console.log("✅ Saved to DB: ", messageResult.rows[0]);

            const newMessage = {
                sender_id: senderId,
                receiver_id: receiverId,
                fullname: senderName,
                profile_image: profileImage,
                message: message,
                message_type: messageType,
                message_id: messageResult.rows[0].id,
                created_at: messageResult.rows[0].created_at
            };

            io.to(`user_${receiverId}`).emit("receiveMessage", newMessage);
            io.to(`user_${senderId}`).emit("receiveMessage", newMessage);

            console.log(`📨 Message sent from ${senderName} (${senderId}) to ${receiverId}: ${message}`);
        } catch (error) {
            console.error("❌ Error sending message:", error);
        }
    });


    socket.on("disconnect", () => {
        console.log("User disconnected:", socket.id);
    });
});



//api ดึงรายชื่อเพื่อนที่เคยแชท
app.get('/api/chat/history', async (req, res) => {
    const { userId } = req.query;

    console.log(`📢 Fetching chat history for userId: ${userId}`); // Debug Log

    const query = `
    SELECT DISTINCT ON (LEAST(m.sender_id, m.receiver_id), GREATEST(m.sender_id, m.receiver_id)) 
    u.id AS friend_id, 
    COALESCE(u.fullname, 'Unknown') AS fullname, 
    COALESCE(u.profile_image, '') AS profile_image, 
    m.message, 
    m.created_at,
    EXISTS (
        SELECT 1 
        FROM messages m2 
        WHERE m2.receiver_id = $1 
          AND m2.sender_id = u.id 
          AND m2.is_unread = true
    ) AS is_unread
FROM messages m
JOIN users u ON u.id = CASE 
    WHEN m.sender_id = $1 THEN m.receiver_id 
    ELSE m.sender_id 
END
WHERE (m.sender_id = $1 OR m.receiver_id = $1)
ORDER BY LEAST(m.sender_id, m.receiver_id), GREATEST(m.sender_id, m.receiver_id), m.created_at DESC;
    `;

    try {
        const result = await pool.query(query, [userId]);
        console.log("📌 Chat History API Response:", result.rows);  // ✅ Debug log
        res.status(200).json(result.rows);
    } catch (error) {
        console.error("Error fetching chat history:", error);
        res.status(500).json({ error: "Server error" });
    }
});

//api ดึงประวัติแชท
app.get('/api/chat/messages', async (req, res) => {
    const { sender_id, receiver_id } = req.query;

    const query = `
    SELECT id, sender_id, receiver_id, message, message_type, created_at, is_unread 
    FROM messages 
    WHERE (sender_id = $1 AND receiver_id = $2) 
       OR (sender_id = $2 AND receiver_id = $1) 
    ORDER BY created_at ASC;
    `;

    try {
        const result = await pool.query(query, [sender_id, receiver_id]);
        res.status(200).json(result.rows);
    } catch (error) {
        console.error("Error fetching chat messages:", error);
        res.status(500).json({ error: "Server error" });
    }
});

app.post('/api/chat/markAsRead', async (req, res) => {
    const { user_id, friend_id } = req.body;

    const query = `
    UPDATE messages
    SET is_unread = false
    WHERE sender_id = $1 AND receiver_id = $2 AND is_unread = true;
    `;

    try {
        await pool.query(query, [friend_id, user_id]);
        res.status(200).json({ success: true, message: "Messages marked as read" });
    } catch (error) {
        console.error("Error marking messages as read:", error);
        res.status(500).json({ error: "Server error" });
    }
});

// API ดึงจำนวนข้อความที่ยังไม่ได้อ่าน
app.get('/api/chat/unreadCount', async (req, res) => {
    const { userId } = req.query;

    try {
        const query = `
        SELECT COUNT(*) AS unread_count
        FROM messages
        WHERE receiver_id = $1 AND is_unread = true;
      `;

        const result = await pool.query(query, [userId]);
        res.status(200).json({ unread_count: result.rows[0].unread_count });
    } catch (error) {
        console.error("Error fetching unread messages count:", error);
        res.status(500).json({ error: "Server error" });
    }
});


// ตั้งค่า multer สำหรับอัปโหลดไฟล์ไปที่โฟลเดอร์ `messages/`
const messagestorage = multer.diskStorage({
    destination: (req, file, cb) => {
        const dir = path.join(__dirname, 'messages'); // เปลี่ยนเป็นโฟลเดอร์ `messages/`
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true }); // สร้างโฟลเดอร์หากไม่มีอยู่
        }
        cb(null, dir);
    },
    filename: (req, file, cb) => {
        cb(null, Date.now() + path.extname(file.originalname)); // ตั้งชื่อไฟล์ด้วย timestamp
    },
});

const messageupload = multer({ storage: messagestorage });

// เสิร์ฟไฟล์จาก `messages/`
app.use('/messages', express.static(path.join(__dirname, 'messages')));

// API สำหรับอัปโหลดรูปภาพ
app.post("/api/messages_image", messageupload.single("image"), async (req, res) => {
    if (!req.file) {
        return res.status(400).json({ error: "No image uploaded" });
    }

    const imageUrl = `/messages/${req.file.filename}`; // URL ของรูปที่ถูกเก็บในโฟลเดอร์ `messages/`
    res.status(200).json({ imageUrl });
});


server.listen(port, () => {
    console.log(`Server running on port ${port}`);
});