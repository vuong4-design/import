const mongoose = require('mongoose');

const productSchema = new mongoose.Schema({
    bundle_id: { type: String, required: true },
    product_id: { type: String, required: true },
    product_name: String,
    price: Number,
    currency: String,
    description: String,
    collected_at: { type: Date, default: Date.now }
});

// Composite index to avoid duplicates
productSchema.index({ bundle_id: 1, product_id: 1 }, { unique: true });

module.exports = mongoose.model('Product', productSchema);
