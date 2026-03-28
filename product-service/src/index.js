const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
require('dotenv').config();

const { connectDB } = require('./config/database');
const productRoutes = require('./routes/product.routes');

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const Product = require('./models/product.model');

const seedProducts = async () => {
  const products = [
    {
      name: 'Wireless Bluetooth Headphones',
      description: 'Premium over-ear headphones with active noise cancellation and 30-hour battery life.',
      price: 129.99,
      sku: 'AUDIO-001',
      category: 'Electronics',
      stock: 50
    },
    {
      name: 'Smart Fitness Watch',
      description: 'Track your workouts, heart rate, and sleep with this water-resistant smartwatch.',
      price: 199.99,
      sku: 'WEARABLE-001',
      category: 'Electronics',
      stock: 30
    },
    {
      name: 'Organic Coffee Beans',
      description: 'Single-origin Ethiopian coffee beans, freshly roasted, 1kg bag.',
      price: 24.99,
      sku: 'GROCERY-001',
      category: 'Food & Beverage',
      stock: 100
    },
    {
      name: 'Ergonomic Office Chair',
      description: 'Adjustable lumbar support, breathable mesh back, perfect for long work sessions.',
      price: 349.99,
      sku: 'FURNITURE-001',
      category: 'Furniture',
      stock: 20
    },
    {
      name: 'Portable Power Bank',
      description: '20000mAh high-capacity power bank with fast charging and dual USB ports.',
      price: 49.99,
      sku: 'ACCESSORY-001',
      category: 'Electronics',
      stock: 75
    }
  ];

  try {
    for (const product of products) {
      await Product.findOrCreate({
        where: { sku: product.sku },
        defaults: product
      });
    }
    console.log('Product Service: 5 products seeded successfully');
  } catch (error) {
    console.error('Product Service: Failed to seed products:', error.message);
  }
};

// Database connection
connectDB().then(() => {
  seedProducts();
});

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    res.status(200).json({
      status: 'UP',
      service: 'product-service',
      timestamp: new Date().toISOString(),
      uptime: process.uptime()
    });
  } catch (error) {
    res.status(503).json({
      status: 'DOWN',
      error: error.message
    });
  }
});

// Routes
app.use('/products', productRoutes);

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, () => {
  console.log(`Product Service running on port ${PORT}`);
});

module.exports = app;
