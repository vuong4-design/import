const mongoose = require('mongoose');

const inventorySchema = new mongoose.Schema({
    user_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    bundle_id: String,
    product_id: String,
    product_name: String,
    transaction_id: { type: String, unique: true },
    receipt: String,
    transaction_date: Date,
    status: { type: String, enum: ['exported', 'imported', 'pending'], default: 'exported' },
    price: Number,
    created_at: { type: Date, default: Date.now },
    updated_at: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Inventory', inventorySchema);
