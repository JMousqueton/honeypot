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
  firstListIcon: 'tool',
  secondListIcon: 'shield',

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
      {
        name: 'Tableau InCyber',
        link: '/kibana/app/dashboards#/view/8d4e8300-ebde-11e8-9675-1b303bfb38ef?_g=h@3a04046',
      },
    ],
  },
};