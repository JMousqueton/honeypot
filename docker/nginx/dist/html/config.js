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
  greetingMorning: 'Bonour ☕',
  greetingAfternoon: 'Bon après-midi 🍯',
  greetingEvening: 'Bonne soirée 😁',
  greetingNight: 'Bonne nuit 🥱',

  // ┬  ┬┌─┐┌┬┐┌─┐
  // │  │└─┐ │ └─┐
  // ┴─┘┴└─┘ ┴ └─┘

  //Icons
  firstListIcon: 'home',
  secondListIcon: 'external-link',
  // Previous version 
  // firstListIcon: 'gauge',
  // secondListIcon: 'home',

  // Links
  lists: {
    firstList: [
      {
        name: 'Administration Serveur',
        link: '/cockpit.html',
      },
      {
        name: 'Administration ELK',
        link: '/elasticvue/',
      },
    ],
    secondList: [
      {
        name: 'Tableau de bord principal',
        link: 'https://sicherheitstacho.eu',
      },
      {
        name: 'Attaques en temps-réel',
        link: '/map/',
      },
      {
        name: 'Tous les Tableaux de bord',
        link: '/kibana',
      },      
    ],
  },
};
