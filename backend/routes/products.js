const express = require('express');
const router = express.Router();
const Product = require('../models/Product');
const auth = require('../middleware/auth'); // Optional: enforce auth for collection?

// Collect products
router.post('/collect', async (req, res) => {
    try {
        const { bundle_id, products } = req.body;
        if (!bundle_id || !products) return res.status(400).json({ error: 'Data missing' });

        const operations = products.map(p => ({
            updateOne: {
                filter: { bundle_id, product_id: p.product_id },
                update: {
                    $set: {
                        product_name: p.product_name,
                        price: p.price,
                        currency: p.currency,
                        description: p.description,
                        collected_at: new Date()
                    }
                },
                upsert: true
            }
        }));

        await Product.bulkWrite(operations);
        res.json({ success: true, count: products.length });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Get products by bundle ID
router.get('/', async (req, res) => {
    try {
        const { bundle_id } = req.query;
        if (!bundle_id) return res.status(400).json({ error: 'Bundle ID required' });

        // Sort by price if possible?
        const products = await Product.find({ bundle_id }).sort({ price: 1 });
        res.json({ products });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;
