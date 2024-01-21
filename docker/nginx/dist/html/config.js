// ╔╗ ╔═╗╔╗╔╔╦╗╔═╗
// ╠╩╗║╣ ║║║ ║ ║ ║
// ╚═╝╚═╝╝╚╝ ╩ ╚═╝
// ┌─┐┌─┐┌┐┌┌─┐┬┌─┐┬ ┬┬─┐┌─┐┌┬┐┬┌─┐┌┐┌
// │  │ ││││├┤ ││ ┬│ │├┬┘├─┤ │ ││ ││││
// └─┘└─┘┘└┘└  ┴└─┘└─┘┴└─┴ ┴ ┴ ┴└─┘┘└┘

const CONFIG = {
  // ┌┐ ┌─┐┌─┐┬┌─┐┌─┐
  // ├┴┐├─┤└─┐││  └─┐
  // └─┘┴ ┴└─┘┴└─┘└─┘

  // General
  imageBackground: true,
  openInNewTab: true,
  twelveHourFormat: false,

  // Greetings
  greetingMorning: 'Bonjour ☕',
  greetingAfternoon: 'Bon après-midi 🍯',
  greetingEvening: 'Bonne soirée 😁',
  greetingNight: 'Bonne nuit 🥱',


  // ┬  ┬┌─┐┌┬┐┌─┐
  // │  │└─┐ │ └─┐
  // ┴─┘┴└─┘ ┴ └─┘

  //Icons
  firstListIcon: 'home',
  secondListIcon: 'external-link',

  // Links
  lists: {
    firstList: [
      {
        name: 'Administration serveur',
        link: '/cockpit.html',
      },
      {
        name: 'Administration ELK',
        link: '/elasticvue/',
      },
    ],
    secondList: [
      {
        name: 'Attaques temps-réel',
        link: '/map/',
      },
      {
        name: 'Tableaux de bord',
        link: '/kibana/',
      },
    ],
  },
};
