require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const { connectDB } = require('./config/database');
const authRoutes = require('./routes/auth.routes');

const app = express();
const PORT = process.env.PORT || 3003;

app.use(helmet());
app.use(cors());
app.use(express.json());

app.use('/auth', authRoutes);

app.get('/health', (req, res) => {
  res.json({ status: 'OK', service: 'user-service', timestamp: new Date().toISOString() });
});

app.get('/', (req, res) => {
  res.json({ message: 'User Service API', endpoints: ['/auth/register', '/auth/login', '/auth/profile'] });
});

const startServer = async () => {
  await connectDB();
  app.listen(PORT, () => {
    console.log(`User Service running on port ${PORT}`);
  });
};

startServer();
