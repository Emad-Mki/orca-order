const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(
  path.join(__dirname, '..', 'Code.gs'),
  'utf8',
);

function createServer(products) {
  const context = vm.createContext({});
  vm.runInContext(source, context);
  context._all = (sheet) => sheet === 'Products' ? products : [];
  context._buildImageIndexMaps_ = () => ({});
  context._findIndexedProductImage_ = () => null;
  return context;
}

function createCsvImportServer(csv) {
  const headers = [
    'code',
    'name',
    'unit_1',
    'unit_2',
    'factor_2',
    'unit_3',
    'factor_3',
    'display_price',
    'price_2',
    'price_3',
    'wholesale_price',
    'quantity_price',
    'quantity_threshold',
    'quantity_unit',
    'currency',
    'quantity',
    'minimum_stock',
    'updated_at',
    'updated_by',
  ];
  const rows = [headers];
  const sheet = {
    getDataRange: () => ({ getValues: () => rows }),
    getRange: (rowIndex) => ({
      setValues: (values) => { rows[rowIndex - 1] = values[0]; },
    }),
    appendRow: (row) => rows.push(row),
  };
  const server = createServer([]);
  server._ss = () => ({ getSheetByName: () => sheet });
  server.DriveApp = {
    getFileById: () => ({
      getBlob: () => ({ getDataAsString: () => csv }),
    }),
  };
  server.Utilities = {
    parseCsv: (content) => content.split(/\r?\n/).map(line => line.split(',')),
  };
  return { server, rows, headers };
}

const product = {
  code: 'P1',
  name: 'Test product',
  unit_1: 'piece',
  unit_2: 'box',
  factor_2: 2,
  unit_3: 'half-box',
  factor_3: 0.5,
  display_price: 10,
  wholesale_price: 7,
  quantity_price: 6,
  quantity_threshold: 4,
  quantity_unit: 'box',
  currency: 'USD',
};

test('product APIs omit wholesale price unless the authenticated user is allowed', () => {
  const server = createServer([product]);

  for (const result of [
    server._handleProducts(
      { can_view_wholesale_price: true },
      { role: 'customer', can_view_wholesale_price: false },
    ),
    server._handleSearchProducts(
      { query: 'P1', can_view_wholesale_price: true },
      { role: 'customer', can_view_wholesale_price: false },
    ),
  ]) {
    assert.equal(result.products.length, 1);
    assert.equal('wholesale_price' in result.products[0], false);
  }

  const branchManager = server._handleProducts(
    { can_view_wholesale_price: true },
    { role: 'manager', can_view_wholesale_price: false },
  );
  assert.equal('wholesale_price' in branchManager.products[0], false);
  assert.equal('quantity_price' in branchManager.products[0], false);

  const explicitlyAllowed = server._handleProducts(
    {},
    { role: 'customer', can_view_wholesale_price: true },
  );
  assert.equal(explicitlyAllowed.products[0].wholesale_price, 7);
});

test('admin and accountant receive wholesale prices and derived unit prices', () => {
  const server = createServer([product]);

  for (const role of ['admin', 'accountant']) {
    const result = server._handleProducts(
      {},
      { role, can_view_wholesale_price: false },
    );
    assert.equal(result.products[0].wholesale_price, 7);
    assert.equal(result.products[0].price_2, 20);
    assert.equal(result.products[0].price_3, 5);
    assert.equal(result.products[0].quantity_price, 6);
  }
});

test('invalid factors fail closed and saved order factors override client claims', () => {
  const server = createServer([]);

  assert.equal(
    server._productPriceForUnit_(
      { unit_1: 'piece', unit_2: 'box', factor_2: 0 },
      10,
      'box',
    ),
    null,
  );
  assert.equal(
    server._orderItemFactorForUnit_(
      { unit_1: 'piece', unit_2: 'box', factor_2: 2 },
      product,
      'box',
    ),
    2,
  );
});

test('customer price suggestions retain invoice source and convert by unit factor', () => {
  const server = createServer([product]);
  server._requireColumns_ = () => {};
  server._now = () => '2026-11-27T12:00:00.000Z';

  const records = server._prepareCustomerPriceSuggestionRecords_(
    {
      customer_id: 'C1',
      order_id: 'INV-1',
      order_number: 'SAL-001',
      currency: 'USD',
    },
    [{ code: 'P1', unit: 'half-box', final_price: 4.25 }],
    { user_id: 'U1' },
    { P1: product },
    'invoice',
  );

  assert.equal(records.length, 1);
  assert.equal(records[0].unit_factor, 0.5);
  assert.equal(records[0].unit_price, 4.25);
  assert.equal(records[0].source_type, 'invoice');
  assert.equal(records[0].source_id, 'INV-1');

  const previous = {
    customer_id: 'C1',
    product_code: 'P1',
    unit: 'piece',
    unit_factor: 1,
    currency: 'USD',
    unit_price: 10,
    updated_at: '2026-11-27T11:00:00.000Z',
  };
  assert.equal(
    server._customerPriceSuggestion_(
      [previous],
      'C1',
      product,
      'box',
      'USD',
      'NEXT-ORDER',
    ).price,
    20,
  );
  assert.equal(
    server._customerPriceSuggestion_(
      [previous],
      'C2',
      product,
      'box',
      'USD',
      'NEXT-ORDER',
    ),
    null,
  );
});

test('CSV import validates and imports all price tiers and conversion columns', () => {
  const csv = [
    'code,name,unit_1,unit_2,factor_2,unit_3,factor_3,display_price,price_2,price_3,wholesale_price,quantity_price,quantity_threshold,quantity_unit,currency,quantity,minimum_stock',
    'P2,Imported,piece,box,2,half-box,0.5,10,999,999,7,6,4,box,USD,12,1',
  ].join('\n');
  const { server, rows, headers } = createCsvImportServer(csv);
  const result = server._handleSyncFromDrive(
    { csv_file_id: 'drive-file' },
    { role: 'admin', user_id: 'admin-1' },
  );

  assert.equal(result.success, true);
  assert.equal(result.details.created, 1);
  const imported = rows[1];
  assert.equal(imported[headers.indexOf('display_price')], 10);
  assert.equal(imported[headers.indexOf('price_2')], '');
  assert.equal(imported[headers.indexOf('price_3')], '');
  assert.equal(imported[headers.indexOf('wholesale_price')], 7);
  assert.equal(imported[headers.indexOf('quantity_price')], 6);
  assert.equal(imported[headers.indexOf('quantity_threshold')], 4);
  assert.equal(imported[headers.indexOf('factor_2')], 2);
  assert.equal(imported[headers.indexOf('factor_3')], 0.5);
  assert.equal(result.details.warnings.length, 2);
});

test('CSV import rejects invalid factors without writing and gates tier prices', () => {
  const invalidCsv = [
    'code,name,unit_1,unit_2,factor_2,display_price',
    'P3,Invalid,piece,box,0,10',
  ].join('\n');
  const invalid = createCsvImportServer(invalidCsv);
  const result = invalid.server._handleSyncFromDrive(
    { csv_file_id: 'drive-file' },
    { role: 'admin', user_id: 'admin-1' },
  );
  assert.equal(result.success, false);
  assert.equal(result.details.errors.length, 1);
  assert.equal(invalid.rows.length, 1);

  const restrictedCsv = [
    'code,name,unit_1,display_price,wholesale_price',
    'P4,Restricted,piece,10,7',
  ].join('\n');
  const restricted = createCsvImportServer(restrictedCsv);
  assert.throws(
    () => restricted.server._handleSyncFromDrive(
      { csv_file_id: 'drive-file' },
      {
        role: 'manager',
        user_id: 'manager-1',
        can_view_wholesale_price: true,
      },
    ),
    error => error.code === 'FORBIDDEN',
  );
});
