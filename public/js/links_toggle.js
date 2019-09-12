/*
 * Show or hide blocks of links on the right-hand side of the page
 **/

const yearInView = function yearOfPostBeingViewed() {
  return Number(window.location.href.split('/').reverse()[0].split('-')[0]);
};

const buttonElement = function toggleButtonElement(year) {
  return document.getElementById(`#toggle_${year}`);
};

const blockElement = function yearBlockElement(year) {
  return document.getElementById(`#block_${year}`);
};

const toggleBlock = function showOrHideYearBlock(year) {
  const button = buttonElement(year);
  const block = blockElement(year);

  if (button.innerText == '+') {
    expandBlock(button, block);
  } else {
    collapseBlock(button, block);
  }
};

const expandBlock = function expandYearBlock(button, block) {
  button.innerText = '-';
  block.style.display = 'block';
};

const collapseBlock = function collapseYearBlock(button, block) {
  button.innerText = '+';
  block.style.display = 'none';
};

const collapseOldYears = function collapseOldYearBlocks() {
  const years = document.getElementsByClassName('year_toggle');
  const yearToSkip = yearInView();

  for (let i = 5; i < years.length; i++) {
    const year = years[i].id.replace('#toggle_', '');

    if (year != yearToSkip) {
      collapseBlock(buttonElement(year), blockElement(year));
    }
  }
};

window.onload = function() {
  collapseOldYears();
};
