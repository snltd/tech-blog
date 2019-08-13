const yearsToShow = 4;
const expandButton = '+';
const collapseButton = '-'; // must match the Slim template

const collapseBlock = function collapseLinkBlock(element) {
  element.innerText = expandButton;
  element.nextElementSibling.style.display = 'none';
};

const expandBlock = function expandLinkBlock(element) {
  element.innerText = collapseButton;
  element.nextElementSibling.style.display = 'block';
};

const yearInView = function yearOfPostBeingViewed() {
  return window.location.href.split('/').reverse()[0].split('-')[0];
};

const yearsToCollapse = function (refs) {
  const recentYears = Object.keys(refs).sort().slice(0, 0 - yearsToShow);
  const yiv = yearInView();

  if (yiv === '') {
    return recentYears;
  }

  return recentYears.filter((y) => !y.endsWith(yearInView()));
};

const vm = new Vue({
  el: 'nav',
  methods: {
    toggleBlock(ev) {
      if (ev.target.innerText === collapseButton) {
        collapseBlock(ev.target);
      } else {
        expandBlock(ev.target);
      }
    },
  },
  mounted() {
    console.log(yearsToCollapse(this.$refs));
    yearsToCollapse(this.$refs).forEach((year) => {
      collapseBlock(this.$refs[year]);
    });
  },
});
