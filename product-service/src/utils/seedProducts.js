const { Product } = require('../models/product.model');

const seedProducts = async () => {
  const products = [
    {
      name: 'Wireless Bluetooth Headphones',
      price: 89.99,
      sku: 'WBH-001',
      stock: 50,
      category: 'Electronics',
      description: 'Premium wireless headphones with noise cancellation and 30-hour battery life'
    },
    {
      name: 'Smart Fitness Watch',
      price: 199.99,
      sku: 'SFW-002',
      stock: 30,
      category: 'Electronics',
      description: 'Track your health with heart rate monitor, GPS, and sleep tracking'
    },
    {
      name: 'Organic Cotton T-Shirt',
      price: 29.99,
      sku: 'OCT-003',
      stock: 100,
      category: 'Clothing',
      description: 'Comfortable 100% organic cotton t-shirt available in multiple colors'
    },
    {
      name: 'Stainless Steel Water Bottle',
      price: 24.99,
      sku: 'SSWB-004',
      stock: 75,
      category: 'Home',
      description: 'Eco-friendly insulated bottle keeps drinks cold for 24 hours or hot for 12 hours'
    },
    {
      name: 'Leather Laptop Bag',
      price: 79.99,
      sku: 'LLB-005',
      stock: 25,
      category: 'Accessories',
      description: 'Genuine leather bag fits up to 15-inch laptops with multiple compartments'
    }
  ];

  try {
    // Check if products already exist
    const existingCount = await Product.count();
    if (existingCount > 0) {
      console.log(`Products already seeded: ${existingCount} products exist`);
      return;
    }

    await Product.bulkCreate(products);
    console.log('Successfully seeded 5 products');
  } catch (error) {
    console.error('Error seeding products:', error);
  }
};

module.exports = seedProducts;
