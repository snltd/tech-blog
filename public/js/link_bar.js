// Handle hiding and revealing of years in the links column
//
function block_id(offset) {
  return '#' + blocks._groups[0][offset].id;
}

function button_id(offset) {
  return '#' + buttons._groups[0][offset].id;
}

function flip_block(offset, style) {
  var button_txt = (style == 'none') ? '+' : '-';
  d3.select(button_id(offset)).text(button_txt);
  d3.select(block_id(offset)).style('display', style);
}

function year_in_view() {
  return window.location.href.split('/').reverse()[0].split('-')[0];
}

var years = d3.selectAll('.page_year'),
    buttons = d3.selectAll('.year_toggle'),
    state = new Array(years.size() + 1).join('0').split('').map(parseFloat),
    blocks = d3.selectAll('.page_block'),
    block_in_view = '#block_' + year_in_view();

state.forEach(function(d, i) {
  if (i < 4 || block_id(i) === block_in_view) {
    state[i] = 1;
  } else {
    flip_block(i, 'none');
  }
});

years.data(state).on('click', function(d, offset) {
  var style = 'contents';

  if (d === 0) {
    state[offset] = 1;
  } else {
    state[offset] = 0;
    style = 'none';
  }

  flip_block(offset, style);
  years.data(state);
});
