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
    if (!token) return res.sendStatus(401);

    jwt.verify(token, SECRET_KEY, (err, user) => {
        if (err) return res.sendStatus(403);
        req.user = user;
        next();
    });
};

// Login Endpoint
app.post('/api/login', async (req, res) => {
    const { username, password } = req.body;
    const query = 'SELECT id, password FROM users WHERE username = $1';
    try {
        const result = await pool.query(query, [username]);
        if (result.rows.length > 0) {
            const user = result.rows[0];
            const validPassword = await bcrypt.compare(password, user.password);
            if (validPassword) {
                const token = jwt.sign({ id: user.id }, SECRET_KEY, { expiresIn: '1h' });
                res.json({ id: user.id, token });
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

        // เพิ่มผู้ใช้ใหม่
        const result = await pool.query(
            'INSERT INTO users (username, password, email, fullname, gender, birthdate) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *',
            [username, hashedPassword, email, fullname, gender, birthdate]
        );
        res.json(result.rows[0]);
    } catch (error) {
        res.status(500).json({ error: error.message });
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
        cb(null, Date.now() + path.extname(file.originalname));
    },
});

const foodUpload = multer({ storage: foodStorage });

app.post('/api/food', foodUpload.single('image'), async (req, res) => {
    const { province, name, description, latitude, longitude } = req.body;
    console.log('Request body:', req.body); // ดูข้อมูล request ที่ส่งมา
    console.log('Request file:', req.file); // ตรวจสอบไฟล์

    if (!province || !name || !latitude || !longitude) {
        return res.status(400).json({ error: 'Province, Name, latitude, and longitude are required.' });
    }

    const imagePath = req.file ? `/foodimage/${req.file.filename}` : null;

    try {
        const result = await pool.query(
            `INSERT INTO food (province, name, image, description, latitude, longitude) 
            VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
            [province, name, imagePath, description, latitude, longitude]
        );
        res.status(201).json(result.rows[0]);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/food', async (req, res) => {
    try {
        const { province, name } = req.query; // ดึงค่าที่ใช้ค้นหา
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

        if (conditions.length > 0) {
            query += ' WHERE ' + conditions.join(' OR '); // ใช้ OR เพื่อให้ค้นหาได้ทั้ง 2 ฟิลด์
        }

        // ดึงข้อมูลจาก PostgreSQL
        const result = await pool.query(query, values);
        let foodData = result.rows;

        // **เรียงลำดับข้อมูล**: ตรงมากที่สุดขึ้นก่อน
        foodData.sort((a, b) => {
            let scoreA = (province && a.province.toLowerCase().startsWith(province.toLowerCase()) ? 1 : 0) +
                (name && a.name.toLowerCase().startsWith(name.toLowerCase()) ? 1 : 0);
            let scoreB = (province && b.province.toLowerCase().startsWith(province.toLowerCase()) ? 1 : 0) +
                (name && b.name.toLowerCase().startsWith(name.toLowerCase()) ? 1 : 0);
            return scoreB - scoreA; // เรียงจากคะแนนมากไปน้อย
        });

        // ตรวจสอบให้แน่ใจว่ามีข้อมูล latitude และ longitude
        foodData = foodData.map(food => ({
            ...food,
            latitude: food.latitude || 0.0,
            longitude: food.longitude || 0.0
        }));

        res.json(foodData);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

app.use('/foodimage', express.static(path.join(__dirname, 'foodimage')));

//hotel
const hotelStorage = multer.diskStorage({
    destination: path.join(__dirname, 'hotelimage'), // Save files to hotelimage folder
    filename: (req, file, cb) => {
        cb(null, Date.now() + path.extname(file.originalname));
    },
});

const hotelUpload = multer({ storage: hotelStorage });

app.post('/api/hotel', hotelUpload.single('image'), async (req, res) => {
    const { province, name, description, latitude, longitude } = req.body;
    console.log('Request body:', req.body); // ดูข้อมูล request ที่ส่งมา
    console.log('Request file:', req.file); // ตรวจสอบไฟล์

    if (!province || !name || !latitude || !longitude) {
        return res.status(400).json({ error: 'Province, Name, latitude, and longitude are required.' });
    }

    const imagePath = req.file ? `/hotelimage/${req.file.filename}` : null;

    try {
        const result = await pool.query(
            `INSERT INTO hotel (province, name, image, description, latitude, longitude) 
            VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
            [province, name, imagePath, description, latitude, longitude]
        );
        res.status(201).json(result.rows[0]);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/hotel', async (req, res) => {
    try {
        const { province, name } = req.query; // ดึงค่าที่ใช้ค้นหา
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

        if (conditions.length > 0) {
            query += ' WHERE ' + conditions.join(' OR '); // ใช้ OR เพื่อให้ค้นหาได้ทั้ง 2 ฟิลด์
        }

        // ดึงข้อมูลจาก PostgreSQL
        const result = await pool.query(query, values);
        let hotelData = result.rows;

        // **เรียงลำดับข้อมูล**: ตรงมากที่สุดขึ้นก่อน
        hotelData.sort((a, b) => {
            let scoreA = (province && a.province.toLowerCase().startsWith(province.toLowerCase()) ? 1 : 0) +
                (name && a.name.toLowerCase().startsWith(name.toLowerCase()) ? 1 : 0);
            let scoreB = (province && b.province.toLowerCase().startsWith(province.toLowerCase()) ? 1 : 0) +
                (name && b.name.toLowerCase().startsWith(name.toLowerCase()) ? 1 : 0);
            return scoreB - scoreA; // เรียงจากคะแนนมากไปน้อย
        });

        // ตรวจสอบให้แน่ใจว่ามีข้อมูล latitude และ longitude
        hotelData = hotelData.map(hotel => ({
            ...hotel,
            latitude: hotel.latitude || 0.0,
            longitude: hotel.longitude || 0.0
        }));

        res.json(hotelData);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

app.use('/hotelimage', express.static(path.join(__dirname, 'hotelimage')));

//tourist
const touristStorage = multer.diskStorage({
    destination: path.join(__dirname, 'touristimage'), // Save files to touristimage folder
    filename: (req, file, cb) => {
        cb(null, Date.now() + path.extname(file.originalname));
    },
});

const touristUpload = multer({ storage: touristStorage });

app.post('/api/tourist', touristUpload.single('image'), async (req, res) => {
    const { province, name, description, latitude, longitude } = req.body;
    console.log('Request body:', req.body); // ดูข้อมูล request ที่ส่งมา
    console.log('Request file:', req.file); // ตรวจสอบไฟล์

    if (!province || !name || !latitude || !longitude) {
        return res.status(400).json({ error: 'Province, Name, latitude, and longitude are required.' });
    }

    const imagePath = req.file ? `/touristimage/${req.file.filename}` : null;

    try {
        const result = await pool.query(
            `INSERT INTO tourist (province, name, image, description, latitude, longitude) 
            VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
            [province, name, imagePath, description, latitude, longitude]
        );
        res.status(201).json(result.rows[0]);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/tourist', async (req, res) => {
    try {
        const { province, name } = req.query; // ดึงค่าที่ใช้ค้นหา
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

        if (conditions.length > 0) {
            query += ' WHERE ' + conditions.join(' OR '); // ใช้ OR เพื่อให้ค้นหาได้ทั้ง 2 ฟิลด์
        }

        // ดึงข้อมูลจาก PostgreSQL
        const result = await pool.query(query, values);
        let touristData = result.rows;

        // **เรียงลำดับข้อมูล**: ตรงมากที่สุดขึ้นก่อน
        touristData.sort((a, b) => {
            let scoreA = (province && a.province.toLowerCase().startsWith(province.toLowerCase()) ? 1 : 0) +
                (name && a.name.toLowerCase().startsWith(name.toLowerCase()) ? 1 : 0);
            let scoreB = (province && b.province.toLowerCase().startsWith(province.toLowerCase()) ? 1 : 0) +
                (name && b.name.toLowerCase().startsWith(name.toLowerCase()) ? 1 : 0);
            return scoreB - scoreA; // เรียงจากคะแนนมากไปน้อย
        });

        // ตรวจสอบให้แน่ใจว่ามีข้อมูล latitude และ longitude
        touristData = touristData.map(tourist => ({
            ...tourist,
            latitude: tourist.latitude || 0.0,
            longitude: tourist.longitude || 0.0
        }));

        res.json(touristData);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
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

const postupload = multer({ storage: poststorage });

app.use('/posts', express.static(path.join(__dirname, 'posts')));

// POST: เพิ่มข้อมูลลงในตาราง post พร้อมเชื่อมโยง user_id จาก token
app.post('/api/posts', authenticateToken, postupload.single('image'), async (req, res) => {
    const user_id = req.user.id; // ดึง id จาก token ที่ถอดรหัสแล้ว
    const { province, description } = req.body;
    const image = req.file ? req.file.filename : null;

    try {
        const result = await pool.query(
            `INSERT INTO post (user_id, province, description, image, date) 
            VALUES ($1, $2, $3, $4, NOW()) RETURNING *`,
            [user_id, province, description, image]
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
        const { province } = req.query;
        let query = `
      SELECT 
          post.post_id, 
          post.user_id, 
          post.province, 
          post.description, 
          post.image, 
          post.date,
          users.fullname, 
          users.profile_image,
          COALESCE(COUNT(comment.comment_id), 0)::INTEGER AS comment_count  -- ✅ แปลงให้เป็น Integer
      FROM post
      JOIN users ON post.user_id = users.id
      LEFT JOIN comment ON post.post_id = comment.post_id  -- ✅ เชื่อมกับตารางคอมเมนต์
    `;

        let values = [];
        if (province) {
            query += ` WHERE LOWER(post.province) LIKE $1`;
            values.push(`%${province.toLowerCase()}%`);
        }

        query += ` GROUP BY post.post_id, users.id ORDER BY post.date DESC`;

        const result = await pool.query(query, values);
        res.json(result.rows);
    } catch (err) {
        console.error('Database error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// DELETE: ลบโพสต์ได้เฉพาะเจ้าของโพสต์เท่านั้น
app.delete('/api/posts/:post_id', authenticateToken, async (req, res) => {
    const { post_id } = req.params;
    const user_id = req.user.id; // user id ที่มาจาก token

    try {
        // ตรวจสอบว่าโพสต์นี้เป็นของ user ที่ขอลบหรือไม่
        const checkPost = await pool.query('SELECT user_id FROM post WHERE post_id = $1', [post_id]);

        if (checkPost.rows.length === 0) {
            return res.status(404).json({ error: "Post not found" });
        }

        if (checkPost.rows[0].user_id !== user_id) {
            return res.status(403).json({ error: "You can only delete your own posts" });
        }

        // ลบโพสต์
        const result = await pool.query('DELETE FROM post WHERE post_id = $1 RETURNING *', [post_id]);

        if (result.rowCount > 0) {
            io.emit('delete_post', { post_id: parseInt(post_id) }); // 🔥 Broadcast ให้ทุก client ลบโพสต์
            res.json({ message: "Post deleted successfully", post_id: post_id });
        } else {
            res.status(500).json({ error: "Failed to delete post" });
        }
    } catch (error) {
        console.error("Error deleting post:", error);
        res.status(500).json({ error: "Internal server error" });
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
                    u.id AS user_id, u.fullname, u.profile_image 
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

// DELETE: ลบคอมเมนต์
app.delete('/api/comments/:comment_id', authenticateToken, async (req, res) => {
    const comment_id = req.params.comment_id;
    const user_id = req.user.id;

    try {
        const comment = await pool.query('SELECT * FROM comment WHERE comment_id = $1', [comment_id]);
        if (comment.rows.length === 0) {
            return res.status(404).json({ message: "Comment not found" });
        }

        if (comment.rows[0].user_comment_id !== user_id) {
            return res.status(403).json({ message: "You are not allowed to delete this comment" });
        }

        await pool.query('DELETE FROM comment WHERE comment_id = $1', [comment_id]);

        // 📡 แจ้งเตือนให้ทุก client อัปเดตเมื่อมีการลบคอมเมนต์
        io.emit('delete_comment', { comment_id, post_id: comment.rows[0].post_id });

        res.json({ message: "Comment deleted successfully" });
    } catch (err) {
        console.error(err.message);
        res.status(500).json({ message: "Server error" });
    }
});

//reviews
// 📌 เพิ่มรีวิวใหม่
app.post('/api/reviews', authenticateToken, async (req, res) => {
    try {
        const { place_id, review, rating } = req.body;
        const user_id = req.user.id;

        if (!place_id || !review || !rating) {
            return res.status(400).json({ error: 'Missing required fields' });
        }

        // ✅ บังคับให้ rating เป็น int
        const ratingInt = parseInt(rating);
        if (ratingInt < 1 || ratingInt > 5) {
            return res.status(400).json({ error: 'Rating must be between 1 and 5' });
        }

        const newReview = await pool.query(
            `INSERT INTO reviews (user_id, place_id, review, rating) 
             VALUES ($1, $2, $3, $4) RETURNING *`,
            [user_id, place_id, review, ratingInt]
        );

        res.json(newReview.rows[0]);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Server error' });
    }
});


// 📌 ดึงรีวิวของสถานที่
app.get('/api/reviews/:place_id', async (req, res) => {
    try {
        const { place_id } = req.params;

        // ✅ ดึงรีวิวทั้งหมด
        const reviewsQuery = await pool.query(
            `SELECT r.*, u.username, u.profile_image 
             FROM reviews r 
             JOIN users u ON r.user_id = u.id 
             WHERE r.place_id = $1 
             ORDER BY r.created_at DESC`,
            [place_id]
        );

        // ✅ คำนวณค่าเฉลี่ย rating และจำนวนรีวิว
        const statsQuery = await pool.query(
            `SELECT COALESCE(AVG(rating), 0) AS average_rating, COUNT(*) AS review_count 
             FROM reviews 
             WHERE place_id = $1`,
            [place_id]
        );

        res.json({
            reviews: reviewsQuery.rows,
            averageRating: parseFloat(statsQuery.rows[0].average_rating), // ✅ แปลงค่าให้เป็น float
            reviewCount: parseInt(statsQuery.rows[0].review_count) // ✅ แปลงค่าให้เป็น int
        });

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

        const review = await pool.query(
            "DELETE FROM reviews WHERE id = $1 AND user_id = $2 RETURNING *",
            [id, user_id]
        );

        if (review.rowCount === 0) {
            return res.status(403).json({ error: "You can only delete your own reviews" });
        }

        res.json({ message: "Review deleted successfully" });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Server error' });
    }
});


app.listen(port, () => {
    console.log(`Server running on port ${port}`);
});
