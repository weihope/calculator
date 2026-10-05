import { Component } from '@angular/core';
import { IonTabs, IonTabBar, IonTabButton, IonRouterOutlet } from '@ionic/angular/standalone';
import { TranslatePipe } from '@ngx-translate/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-tabs',
  templateUrl: 'tabs.page.html',
  styleUrls: ['tabs.page.scss'],
  standalone: true,
  imports: [IonTabs, IonTabBar, IonTabButton, IonRouterOutlet, TranslatePipe, CommonModule]
})
export class TabsPage {
  constructor() {}
}
