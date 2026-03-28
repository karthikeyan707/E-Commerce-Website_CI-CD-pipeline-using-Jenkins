const { Sequelize } = require('sequelize');

const sequelize = new Sequelize(
  process.env.DB_NAME || 'products_db',
  process.env.DB_USER || 'postgres',
  process.env.DB_PASSWORD || 'password',
  {
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    dialect: 'postgres',
    logging: false,
    pool: {
      max: 5,
      min: 0,
      acquire: 30000,
      idle: 10000
    }
  }
);

const connectDB = async () => {
  try {
    await sequelize.authenticate();
    console.log('Product Service: Database connected successfully.');
    await sequelize.sync({ alter: true });
    console.log('Product Service: Models synchronized.');
  } catch (error) {
    console.error('Product Service: Database connection failed:', error.message);
    process.exit(1);
  }
};

module.exports = { sequelize, connectDB };
