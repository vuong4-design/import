const express = require('express');
const router = express.Router();
const Inventory = require('../models/Inventory');
const auth = require('../middleware/auth');

// Get inventory for a specific bundle ID
router.get('/', auth, async (req, res) => {
    try {
        const { bundle_id } = req.query;
        if (!bundle_id) return res.status(400).json({ error: 'Bundle ID required' });

        const inventory = await Inventory.find({
            user_id: req.user._id,
            bundle_id,
            status: 'exported' // Only show available items
        });

        // Format for client
        const formatted = inventory.map(item => ({
            prod_name: item.product_name,
            prod_id: item.product_id,
            price: item.price,
            quantity: 1, // Assuming 1 per transaction
            inventoryID: item._id
        }));

        res.json({ inventory: formatted });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Check if a product exists in inventory (and can be imported)
router.get('/check', auth, async (req, res) => {
    try {
        const { product_id } = req.query;
        const item = await Inventory.findOne({
            user_id: req.user._id,
            product_id: product_id,
            status: 'exported'
        });

        if (item) {
            res.json({ exists: true, item: { inventoryID: item._id } });
        } else {
            res.json({ exists: false });
        }
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Export transaction (Add to inventory)
router.post('/export', auth, async (req, res) => {
    try {
        const { productID, transactionID, receipt, transactionDate, action } = req.body;

        if (action !== 'export') return res.status(400).json({ error: 'Invalid action' });

        // Check duplication
        const existing = await Inventory.findOne({ transaction_id: transactionID });
        if (existing) return res.json({ success: true, message: 'Already exported' });

        const newItem = new Inventory({
            user_id: req.user._id,
            bundle_id: req.body.bundle_id || 'unknown', // Need client to send bundleID if possible, or extract from receipt
            product_id: productID,
            product_name: productID, // Client should send names or we look it up
            transaction_id: transactionID,
            receipt: receipt,
            transaction_date: new Date(transactionDate * 1000),
            status: 'exported'
        });

        await newItem.save();
        res.json({ success: true });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Mark item as imported (Remove from available inventory)
router.post('/import', auth, async (req, res) => {
    try {
        const { inventoryID } = req.body; // or just ID passed as string
        const idToUse = inventoryID || req.body.id;

        const item = await Inventory.findOne({ _id: idToUse, user_id: req.user._id });
        if (!item) return res.status(404).json({ error: 'Item not found' });

        item.status = 'imported';
        item.updated_at = new Date();
        await item.save();

        res.json({ success: true });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;
