import {
  formatCampaigns,
  filterCampaigns,
  isPatternMatchingWithURL,
} from '../campaignHelper';
import campaigns from './campaignFixtures';

global.chatwootWebChannel = {
  workingHoursEnabled: false,
};
describe('#Campaigns Helper', () => {
  describe('#isPatternMatchingWithURL', () => {
    it('returns correct value if a valid URL is passed', () => {
      expect(
        isPatternMatchingWithURL(
          'https://aloochat.ai/pricing*',
          'https://aloochat.ai/pricing/'
        )
      ).toBe(true);

      expect(
        isPatternMatchingWithURL(
          'https://*.aloochat.ai/pricing/',
          'https://app.aloochat.ai/pricing/'
        )
      ).toBe(true);

      expect(
        isPatternMatchingWithURL(
          'https://{*.}?aloochat.ai/pricing?test=true',
          'https://app.aloochat.ai/pricing/?test=true'
        )
      ).toBe(true);

      expect(
        isPatternMatchingWithURL(
          'https://{*.}?aloochat.ai/pricing*\\?*',
          'https://aloochat.ai/pricing/?test=true'
        )
      ).toBe(true);
    });
  });

  describe('formatCampaigns', () => {
    it('should return formatted campaigns if campaigns are passed', () => {
      expect(formatCampaigns({ campaigns })).toStrictEqual([
        {
          id: 1,
          timeOnPage: 3,
          triggerOnlyDuringBusinessHours: false,
          url: 'https://www.aloochat.ai/pricing',
        },
        {
          id: 2,
          triggerOnlyDuringBusinessHours: false,
          timeOnPage: 6,
          url: 'https://www.aloochat.ai/about',
        },
      ]);
    });
  });
  describe('filterCampaigns', () => {
    it('should return filtered campaigns if formatted campaigns are passed', () => {
      expect(
        filterCampaigns({
          campaigns: [
            {
              id: 1,
              timeOnPage: 3,
              url: 'https://www.aloochat.ai/pricing',
              triggerOnlyDuringBusinessHours: false,
            },
            {
              id: 2,
              timeOnPage: 6,
              url: 'https://www.aloochat.ai/about',
              triggerOnlyDuringBusinessHours: false,
            },
          ],
          currentURL: 'https://www.aloochat.ai/about/',
        })
      ).toStrictEqual([
        {
          id: 2,
          timeOnPage: 6,
          url: 'https://www.aloochat.ai/about',
          triggerOnlyDuringBusinessHours: false,
        },
      ]);
    });
    it('should return filtered campaigns if formatted campaigns are passed and business hours enabled', () => {
      expect(
        filterCampaigns({
          campaigns: [
            {
              id: 1,
              timeOnPage: 3,
              url: 'https://www.aloochat.ai/pricing',
              triggerOnlyDuringBusinessHours: false,
            },
            {
              id: 2,
              timeOnPage: 6,
              url: 'https://www.aloochat.ai/about',
              triggerOnlyDuringBusinessHours: true,
            },
          ],
          currentURL: 'https://www.aloochat.ai/about/',
          isInBusinessHours: true,
        })
      ).toStrictEqual([
        {
          id: 2,
          timeOnPage: 6,
          url: 'https://www.aloochat.ai/about',
          triggerOnlyDuringBusinessHours: true,
        },
      ]);
    });
    it('should return empty campaigns if formatted campaigns are passed and business hours disabled', () => {
      expect(
        filterCampaigns({
          campaigns: [
            {
              id: 1,
              timeOnPage: 3,
              url: 'https://www.aloochat.ai/pricing',
              triggerOnlyDuringBusinessHours: true,
            },
            {
              id: 2,
              timeOnPage: 6,
              url: 'https://www.aloochat.ai/about',
              triggerOnlyDuringBusinessHours: true,
            },
          ],
          currentURL: 'https://www.aloochat.ai/about/',
          isInBusinessHours: false,
        })
      ).toStrictEqual([]);
    });
  });
});
